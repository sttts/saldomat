## Amazon S3 manager
## Author: Michal Ludvig <michal@logix.cz>
##         http://www.logix.cz/michal
## License: GPL Version 2

import sys
import os, os.path
import base64
import md5
import sha
import hmac
import httplib
import logging
import mimetypes
from logging import debug, info, warning, error
from stat import ST_SIZE

from Utils import *
from SortedDict import SortedDict
from BidirMap import BidirMap
from Config import Config

class S3Error (Exception):
	def __init__(self, response):
		self.status = response["status"]
		self.reason = response["reason"]
		self.info = {}
		debug("S3Error: %s (%s)" % (self.status, self.reason))
		if response.has_key("headers"):
			for header in response["headers"]:
				debug("HttpHeader: %s: %s" % (header, response["headers"][header]))
		if response.has_key("data"):
			tree = ET.fromstring(response["data"])
			for child in tree.getchildren():
				if child.text != "":
					debug("ErrorXML: " + child.tag + ": " + repr(child.text))
					self.info[child.tag] = child.text

	def __str__(self):
		retval = "%d (%s)" % (self.status, self.reason)
		try:
			retval += (": %s" % self.info["Code"])
		except (AttributeError, KeyError):
			pass
		return retval

class ParameterError(Exception):
	pass

class S3(object):
	http_methods = BidirMap(
		GET = 0x01,
		PUT = 0x02,
		HEAD = 0x04,
		DELETE = 0x08,
		MASK = 0x0F,
		)
	
	targets = BidirMap(
		SERVICE = 0x0100,
		BUCKET = 0x0200,
		OBJECT = 0x0400,
		MASK = 0x0700,
		)

	operations = BidirMap(
		UNDFINED = 0x0000,
		LIST_ALL_BUCKETS = targets["SERVICE"] | http_methods["GET"],
		BUCKET_CREATE = targets["BUCKET"] | http_methods["PUT"],
		BUCKET_LIST = targets["BUCKET"] | http_methods["GET"],
		BUCKET_DELETE = targets["BUCKET"] | http_methods["DELETE"],
		OBJECT_PUT = targets["OBJECT"] | http_methods["PUT"],
		OBJECT_GET = targets["OBJECT"] | http_methods["GET"],
		OBJECT_HEAD = targets["OBJECT"] | http_methods["HEAD"],
		OBJECT_DELETE = targets["OBJECT"] | http_methods["DELETE"],
	)

	codes = {
		"NoSuchBucket" : "Bucket '%s' does not exist",
		"AccessDenied" : "Access to bucket '%s' was denied",
		"BucketAlreadyExists" : "Bucket '%s' already exists",
		}

	## S3 sometimes sends HTTP-307 response 
	redir_map = {}

	def __init__(self, config):
		self.config = config

	def get_connection(self, bucket):
		if self.config.proxy_host != "":
			return httplib.HTTPConnection(self.config.proxy_host, self.config.proxy_port)
		else:
			if self.config.use_https:
				return httplib.HTTPSConnection(self.get_hostname(bucket))
			else:
				return httplib.HTTPConnection(self.get_hostname(bucket))

	def get_hostname(self, bucket):
		if bucket:
			if self.redir_map.has_key(bucket):
				host = self.redir_map[bucket]
			else:
				host = self.config.host_bucket % { 'bucket' : bucket }
		else:
			host = self.config.host_base
		debug('get_hostname(%s): %s' % (bucket, host))
		return host

	def set_hostname(self, bucket, redir_hostname):
		self.redir_map[bucket] = redir_hostname

	def format_uri(self, resource):
		if self.config.proxy_host != "":
			uri = "http://%s%s" % (self.get_hostname(resource['bucket']), resource['uri'])
		else:
			uri = resource['uri']
		debug('format_uri(): ' + uri)
		return uri

	## Commands / Actions
	def list_all_buckets(self):
		request = self.create_request("LIST_ALL_BUCKETS")
		response = self.send_request(request)
		response["list"] = getListFromXml(response["data"], "Bucket")
		return response
	
	def bucket_list(self, bucket, prefix = None):
		def _list_truncated(data):
			## <IsTruncated> can either be "true" or "false" or be missing completely
			is_truncated = getTextFromXml(data, ".//IsTruncated") or "false"
			return is_truncated.lower() != "false"

		def _get_contents(data):
			return getListFromXml(data, "Contents")

		request = self.create_request("BUCKET_LIST", bucket = bucket, prefix = prefix)
		response = self.send_request(request)
		#debug(response)
		list = _get_contents(response["data"])
		while _list_truncated(response["data"]):
			marker = list[-1]["Key"]
			info("Listing continues after '%s'" % marker)
			request = self.create_request("BUCKET_LIST", bucket = bucket,
			                              prefix = prefix, 
			                              marker = self.urlencode_string(marker))
			response = self.send_request(request)
			list += _get_contents(response["data"])
		response['list'] = list
		return response

	def bucket_create(self, bucket, bucket_location = None):
		self.check_bucket_name(bucket)
		headers = SortedDict()
		body = ""
		if bucket_location and bucket_location.strip().upper() != "US":
			body  = "<CreateBucketConfiguration><LocationConstraint>"
			body += bucket_location.strip().upper()
			body += "</LocationConstraint></CreateBucketConfiguration>"
			debug("bucket_location: " + body)
		headers["content-length"] = len(body)
		if self.config.acl_public:
			headers["x-amz-acl"] = "public-read"
		request = self.create_request("BUCKET_CREATE", bucket = bucket, headers = headers)
		response = self.send_request(request, body)
		return response

	def bucket_delete(self, bucket):
		request = self.create_request("BUCKET_DELETE", bucket = bucket)
		response = self.send_request(request)
		return response

	def bucket_info(self, uri):
		request = self.create_request("BUCKET_LIST", bucket = uri.bucket(), extra = "?location")
		response = self.send_request(request)
		response['bucket-location'] = getTextFromXml(response['data'], "LocationConstraint") or "any"
		return response

	def object_put(self, filename, bucket, object, extra_headers = None):
		if not os.path.isfile(filename):
			raise ParameterError("%s is not a regular file" % filename)
		try:
			file = open(filename, "rb")
			size = os.stat(filename)[ST_SIZE]
		except IOError, e:
			raise ParameterError("%s: %s" % (filename, e.strerror))
		headers = SortedDict()
		if extra_headers:
			headers.update(extra_headers)
		headers["content-length"] = size
		content_type = None
		if self.config.guess_mime_type:
			content_type = mimetypes.guess_type(filename)[0]
		if not content_type:
			content_type = self.config.default_mime_type
		debug("Content-Type set to '%s'" % content_type)
		headers["content-type"] = content_type
		if self.config.acl_public:
			headers["x-amz-acl"] = "public-read"
		request = self.create_request("OBJECT_PUT", bucket = bucket, object = object, headers = headers)
		response = self.send_file(request, file)
		response["size"] = size
		return response

	def object_get_file(self, bucket, object, filename):
		try:
			stream = open(filename, "wb")
		except IOError, e:
			raise ParameterError("%s: %s" % (filename, e.strerror))
		return self.object_get_stream(bucket, object, stream)

	def object_get_stream(self, bucket, object, stream):
		request = self.create_request("OBJECT_GET", bucket = bucket, object = object)
		response = self.recv_file(request, stream)
		return response
		
	def object_delete(self, bucket, object):
		request = self.create_request("OBJECT_DELETE", bucket = bucket, object = object)
		response = self.send_request(request)
		return response

	def object_put_uri(self, filename, uri, extra_headers = None):
		if uri.type != "s3":
			raise ValueError("Expected URI type 's3', got '%s'" % uri.type)
		return self.object_put(filename, uri.bucket(), uri.object(), extra_headers)

	def object_get_uri(self, uri, filename):
		if uri.type != "s3":
			raise ValueError("Expected URI type 's3', got '%s'" % uri.type)
		if filename == "-":
			return self.object_get_stream(uri.bucket(), uri.object(), sys.stdout)
		else:
			return self.object_get_file(uri.bucket(), uri.object(), filename)

	def object_delete_uri(self, uri):
		if uri.type != "s3":
			raise ValueError("Expected URI type 's3', got '%s'" % uri.type)
		return self.object_delete(uri.bucket(), uri.object())

	def object_info(self, uri):
		request = self.create_request("OBJECT_HEAD", bucket = uri.bucket(), object = uri.object())
		response = self.send_request(request)
		return response

	def get_acl(self, uri):
		if uri.has_object():
			request = self.create_request("OBJECT_GET", bucket = uri.bucket(), object = uri.object(), extra = "?acl")
		else:
			request = self.create_request("BUCKET_LIST", bucket = uri.bucket(), extra = "?acl")
		acl = {}
		response = self.send_request(request)
		grants = getListFromXml(response['data'], "Grant")
		for grant in grants:
			if grant['Grantee'][0].has_key('DisplayName'):
				user = grant['Grantee'][0]['DisplayName']
			if grant['Grantee'][0].has_key('URI'):
				user = grant['Grantee'][0]['URI']
				if user == 'http://acs.amazonaws.com/groups/global/AllUsers':
					user = "*anon*"
			perm = grant['Permission']
			acl[user] = perm
		return acl

	## Low level methods
	def urlencode_string(self, string):
		encoded = ""
		## List of characters that must be escaped for S3
		## Haven't found this in any official docs
		## but my tests show it's more less correct.
		## If you start getting InvalidSignature errors
		## from S3 check the error headers returned
		## from S3 to see whether the list hasn't
		## changed.
		for c in string:	# I'm not sure how to know in what encoding 
					# 'object' is. Apparently "type(object)==str"
					# but the contents is a string of unicode
					# bytes, e.g. '\xc4\x8d\xc5\xafr\xc3\xa1k'
					# Don't know what it will do on non-utf8 
					# systems.
					#           [hope that sounds reassuring ;-)]
			o = ord(c)
			if (o <= 32 or		# Space and below
			    o == 0x22 or	# "
			    o == 0x23 or	# #
			    o == 0x25 or	# %
			    o == 0x2B or	# + (or it would become <space>)
			    o == 0x3C or	# <
			    o == 0x3E or	# >
			    o == 0x3F or	# ?
			    o == 0x5B or	# [
			    o == 0x5C or	# \
			    o == 0x5D or	# ]
			    o == 0x5E or	# ^
			    o == 0x60 or	# `
			    o >= 123):   	# { and above, including >= 128 for UTF-8
				encoded += "%%%02X" % o
			else:
				encoded += c
		debug("String '%s' encoded to '%s'" % (string, encoded))
		return encoded

	def create_request(self, operation, bucket = None, object = None, headers = None, extra = None, **params):
		resource = { 'bucket' : None, 'uri' : "/" }
		if bucket:
			resource['bucket'] = str(bucket)
			if object:
				resource['uri'] = "/" + self.urlencode_string(object)
		if extra:
			resource['uri'] += extra

		if not headers:
			headers = SortedDict()

		if headers.has_key("date"):
			if not headers.has_key("x-amz-date"):
				headers["x-amz-date"] = headers["date"]
			del(headers["date"])
		
		if not headers.has_key("x-amz-date"):
			headers["x-amz-date"] = time.strftime("%a, %d %b %Y %H:%M:%S +0000", time.gmtime())

		method_string = S3.http_methods.getkey(S3.operations[operation] & S3.http_methods["MASK"])
		signature = self.sign_headers(method_string, resource, headers)
		headers["Authorization"] = "AWS "+self.config.access_key+":"+signature
		param_str = ""
		for param in params:
			if params[param] not in (None, ""):
				param_str += "&%s=%s" % (param, params[param])
			else:
				param_str += "&%s" % param
		if param_str != "":
			resource['uri'] += "?" + param_str[1:]
		debug("CreateRequest: resource[uri]=" + resource['uri'])
		return (method_string, resource, headers)
	
	def send_request(self, request, body = None):
		method_string, resource, headers = request
		info("Processing request, please wait...")
 		conn = self.get_connection(resource['bucket'])
 		conn.request(method_string, self.format_uri(resource), body, headers)
		response = {}
		http_response = conn.getresponse()
		response["status"] = http_response.status
		response["reason"] = http_response.reason
		response["headers"] = convertTupleListToDict(http_response.getheaders())
		response["data"] =  http_response.read()
		debug("Response: " + str(response))
		conn.close()

		if response["status"] == 307:
			## RedirectPermanent
			redir_bucket = getTextFromXml(response['data'], ".//Bucket")
			redir_hostname = getTextFromXml(response['data'], ".//Endpoint")
			self.set_hostname(redir_bucket, redir_hostname)
			info("Redirected to: %s" % (redir_hostname))
			return self.send_request(request, body)

		if response["status"] < 200 or response["status"] > 299:
			raise S3Error(response)
		return response

	def send_file(self, request, file):
		method_string, resource, headers = request
		info("Sending file '%s', please wait..." % file.name)
		conn = self.get_connection(resource['bucket'])
		conn.connect()
		conn.putrequest(method_string, self.format_uri(resource))
		for header in headers.keys():
			conn.putheader(header, str(headers[header]))
		conn.endheaders()
		file.seek(0)
		size_left = size_total = headers.get("content-length")
		while (size_left > 0):
			debug("SendFile: Reading up to %d bytes from '%s'" % (self.config.send_chunk, file.name))
			data = file.read(self.config.send_chunk)
			debug("SendFile: Sending %d bytes to the server" % len(data))
			conn.send(data)
			size_left -= len(data)
			info("Sent %d bytes (%d %% of %d)" % (
				(size_total - size_left),
				(size_total - size_left) * 100 / size_total,
				size_total))
		response = {}
		http_response = conn.getresponse()
		response["status"] = http_response.status
		response["reason"] = http_response.reason
		response["headers"] = convertTupleListToDict(http_response.getheaders())
		response["data"] =  http_response.read()
		conn.close()

		if response["status"] == 307:
			## RedirectPermanent
			redir_bucket = getTextFromXml(response['data'], ".//Bucket")
			redir_hostname = getTextFromXml(response['data'], ".//Endpoint")
			self.set_hostname(redir_bucket, redir_hostname)
			info("Redirected to: %s" % (redir_hostname))
			return self.send_file(request, file)

		if response["status"] < 200 or response["status"] > 299:
			raise S3Error(response)
		return response

	def recv_file(self, request, stream):
		method_string, resource, headers = request
		info("Receiving file '%s', please wait..." % stream.name)
		conn = self.get_connection(resource['bucket'])
		conn.connect()
		conn.putrequest(method_string, self.format_uri(resource))
		for header in headers.keys():
			conn.putheader(header, str(headers[header]))
		conn.endheaders()
		response = {}
		http_response = conn.getresponse()
		response["status"] = http_response.status
		response["reason"] = http_response.reason
		response["headers"] = convertTupleListToDict(http_response.getheaders())

		if response["status"] == 307:
			## RedirectPermanent
			response['data'] = http_response.read()
			redir_bucket = getTextFromXml(response['data'], ".//Bucket")
			redir_hostname = getTextFromXml(response['data'], ".//Endpoint")
			self.set_hostname(redir_bucket, redir_hostname)
			info("Redirected to: %s" % (redir_hostname))
			return self.recv_file(request, stream)

		if response["status"] < 200 or response["status"] > 299:
			raise S3Error(response)

		md5_hash = md5.new()
		size_left = size_total = int(response["headers"]["content-length"])
		size_recvd = 0
		while (size_recvd < size_total):
			this_chunk = size_left > self.config.recv_chunk and self.config.recv_chunk or size_left
			debug("ReceiveFile: Receiving up to %d bytes from the server" % this_chunk)
			data = http_response.read(this_chunk)
			debug("ReceiveFile: Writing %d bytes to file '%s'" % (len(data), stream.name))
			stream.write(data)
			md5_hash.update(data)
			size_recvd += len(data)
			info("Received %d bytes (%d %% of %d)" % (
				size_recvd,
				size_recvd * 100 / size_total,
				size_total))
		conn.close()
		response["md5"] = md5_hash.hexdigest()
		response["md5match"] = response["headers"]["etag"].find(response["md5"]) >= 0
		response["size"] = size_recvd
		if response["size"] != long(response["headers"]["content-length"]):
			warning("Reported size (%s) does not match received size (%s)" % (
				response["headers"]["content-length"], response["size"]))
		debug("ReceiveFile: Computed MD5 = %s" % response["md5"])
		if not response["md5match"]:
			warning("MD5 signatures do not match: computed=%s, received=%s" % (
				response["md5"], response["headers"]["etag"]))
		return response

	def sign_headers(self, method, resource, headers):
		h  = method+"\n"
		h += headers.get("content-md5", "")+"\n"
		h += headers.get("content-type", "")+"\n"
		h += headers.get("date", "")+"\n"
		for header in headers.keys():
			if header.startswith("x-amz-"):
				h += header+":"+str(headers[header])+"\n"
		if resource['bucket']:
			h += "/" + resource['bucket']
		h += resource['uri']
		debug("SignHeaders: " + repr(h))
		return base64.encodestring(hmac.new(self.config.secret_key, h, sha).digest()).strip()

	def check_bucket_name(self, bucket):
		if re.compile("[^A-Za-z0-9\._-]").search(bucket):
			raise ParameterError("Bucket name '%s' contains unallowed characters" % bucket)
		if len(bucket) < 3:
			raise ParameterError("Bucket name '%s' is too short (min 3 characters)" % bucket)
		if len(bucket) > 255:
			raise ParameterError("Bucket name '%s' is too long (max 255 characters)" % bucket)
		return True

