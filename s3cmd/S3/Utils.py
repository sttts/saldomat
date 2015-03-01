## Amazon S3 manager
## Author: Michal Ludvig <michal@logix.cz>
##         http://www.logix.cz/michal
## License: GPL Version 2

import os
import time
import re
import string
import random
import md5
import errno

try:
	import xml.etree.ElementTree as ET
except ImportError:
	import elementtree.ElementTree as ET

def stripTagXmlns(xmlns, tag):
	"""
	Returns a function that, given a tag name argument, removes
	eventual ElementTree xmlns from it.

	Example:
		stripTagXmlns("{myXmlNS}tag") -> "tag"
	"""
	if not xmlns:
		return tag
	return re.sub(xmlns, "", tag)

def fixupXPath(xmlns, xpath, max = 0):
	if not xmlns:
		return xpath
	retval = re.subn("//", "//%s" % xmlns, xpath, max)[0]
	return retval

def parseNodes(nodes, xmlns = ""):
	## WARNING: Ignores text nodes from mixed xml/text.
	## For instance <tag1>some text<tag2>other text</tag2></tag1>
	## will be ignore "some text" node
	retval = []
	for node in nodes:
		retval_item = {}
		for child in node.getchildren():
			name = stripTagXmlns(xmlns, child.tag)
			if child.getchildren():
				retval_item[name] = parseNodes([child], xmlns)
			else:
				retval_item[name] = node.findtext(".//%s" % child.tag)
		retval.append(retval_item)
	return retval

def getNameSpace(element):
	if not element.tag.startswith("{"):
		return ""
	return re.compile("^(\{[^}]+\})").match(element.tag).groups()[0]

def getListFromXml(xml, node):
	tree = ET.fromstring(xml)
	xmlns = getNameSpace(tree)
	nodes = tree.findall('.//%s%s' % (xmlns, node))
	return parseNodes(nodes, xmlns)
	
def getTextFromXml(xml, xpath):
	tree = ET.fromstring(xml)
	xmlns = getNameSpace(tree)
	if tree.tag.endswith(xpath):
		return tree.text
	else:
		return tree.findtext(fixupXPath(xmlns, xpath))

def dateS3toPython(date):
	date = re.compile("\.\d\d\dZ").sub(".000Z", date)
	return time.strptime(date, "%Y-%m-%dT%H:%M:%S.000Z")

def dateS3toUnix(date):
	## FIXME: This should be timezone-aware.
	## Currently the argument to strptime() is GMT but mktime() 
	## treats it as "localtime". Anyway...
	return time.mktime(dateS3toPython(date))

def formatSize(size, human_readable = False):
	size = int(size)
	if human_readable:
		coeffs = ['k', 'M', 'G', 'T']
		coeff = ""
		while size > 2048:
			size /= 1024
			coeff = coeffs.pop(0)
		return (size, coeff)
	else:
		return (size, "")

def formatDateTime(s3timestamp):
	return time.strftime("%Y-%m-%d %H:%M", dateS3toPython(s3timestamp))

def convertTupleListToDict(list):
	retval = {}
	for tuple in list:
		retval[tuple[0]] = tuple[1]
	return retval


_rnd_chars = string.ascii_letters+string.digits
_rnd_chars_len = len(_rnd_chars)
def rndstr(len):
	retval = ""
	while len > 0:
		retval += _rnd_chars[random.randint(0, _rnd_chars_len-1)]
		len -= 1
	return retval

def mktmpsomething(prefix, randchars, createfunc):
	old_umask = os.umask(0077)
	tries = 5
	while tries > 0:
		dirname = prefix + rndstr(randchars)
		try:
			createfunc(dirname)
			break
		except OSError, e:
			if e.errno != errno.EEXIST:
				os.umask(old_umask)
				raise
		tries -= 1

	os.umask(old_umask)
	return dirname

def mktmpdir(prefix = "/tmp/tmpdir-", randchars = 10):
	return mktmpsomething(prefix, randchars, os.mkdir)

def mktmpfile(prefix = "/tmp/tmpfile-", randchars = 20):
	createfunc = lambda filename : os.close(os.open(filename, os.O_CREAT | os.O_EXCL))
	return mktmpsomething(prefix, randchars, createfunc)

def hash_file_md5(filename):
	h = md5.new()
	f = open(filename, "rb")
	h.update(f.read())
	f.close()
	return h.hexdigest()
