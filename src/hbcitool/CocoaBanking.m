//
//  CocoaBanking.mm
//  hbcipref
//
//  Created by Stefan Schimanski on 24.03.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "CocoaBanking.h"

#import "debug.h"
#import "Konto.h"
#import "svnrevision.h"
#import "Version.h"

#include <gwenhywfar/url.h>
#include <aqbanking/banking.h>
#include <aqbanking/jobgettransactions.h>
#include <aqbanking/jobgetbalance.h>
#include <aqbanking/imexporter.h>
#include <aqbanking/message.h>
#include <aqbanking/version.h>
#include <aqhbci/provider.h>
#include <aqhbci/user.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <pwd.h>
#include <string.h>


#define TRANSFERTIMEOUT 120
#define CONNECTTIMEOUT 90

#if (AQBANKING_VERSION_MAJOR > 4) || ((AQBANKING_VERSION_MAJOR == 4) && (AQBANKING_VERSION_MINOR >= 99))
#define AQBANKING5
#elif AQBANKING_VERSION_MAJOR > 3
#define AQBANKING4
#else
#define AQBANKING3
#endif

#ifdef DEBUG
#define AQ_CONFIG_PATH @"/Library/Application Support/Saldomat-%@-debug"
#else
#define AQ_CONFIG_PATH @"/Library/Application Support/Saldomat-%@"
#endif

//#define TAN_DEBUG


@implementation CocoaBanking

- (id)init {
	self = [super init];
	keychain_ = 0;
	ab_ = 0;
	provider_ = 0;
	bankingGeoeffnetFuer_ = nil;
	
#if defined(AQBANKING4) || defined(AQBANKING5) 
	// Gwen-Plugins laden, etwa den ConfigMgr
	GWEN_Init();
	//GWEN_Plugins_Init();
#endif
	
	return self;
}


- (BOOL)openKeychain
{
	keychain_ = 0;
	SecKeychainRef keychain = 0;
	
	// Pfad zur Keychain
	NSString * keychainPath = nil;
	NSArray * paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	if ([paths count] == 0) {
		NSLog(@"Strange: NSSearchPathForDirectoriesInDomains does not give the Library dir.");
		return NO;
	}
	keychainPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:
			@"/Keychains/Saldomat.keychain"];
		
	// Erst oeffnen wir sie nur
#if 0
	NSLog(@"Trying to open keychain at %@", keychainPath);
	OSStatus oss = SecKeychainOpen([keychainPath fileSystemRepresentation], &keychain);
#else
	OSStatus oss = SecKeychainCopyDefault(&keychain);
#endif
	if (oss != 0) {
		fprintf(stderr, "The Saldomat keychain cannot be opened (%ld). "
			"This is not critical. But you will not be able to "
			"store PINs in the keychain.\n", oss);
		return NO;
	}
	
	// erst das hier oeffnet sie wirklich (und erzeugt Fehler, falls es nicht geht)
	SecKeychainStatus status;
	oss = SecKeychainGetStatus(keychain, &status);
	if (oss != 0 && oss != errSecNoSuchKeychain) {
		fprintf(stderr, "Cannot get status of keychain (%ld)\n", oss);
		return NO;
	}
	
#if 0
	// Keychain erstellen, wenn sie nicht existiert
	else if (oss == errSecNoSuchKeychain) {
		NSLog(@"Trying to create keychain.");
		oss = SecKeychainCreate(
			 [keychainPath fileSystemRepresentation],
			 0, // password length 0
			 NULL, // no password
			 YES, // prompt the user
			 NULL, // Default rights, i.e. only hbcitool
			 &keychain
		);
		if (oss != 0 || keychain == 0) {
			fprintf(stderr, "The Saldomat keychain cannot ne created (%d). "
			      "This is not critical. But you will not be able to "
			      "store PINs in the keychain.\n", oss);
			return NO;
		}
		
		// automatisches Locken ausstellen (so wie bei der Login-Keychain auch)
		SecKeychainSettings settings;
		settings.version = SEC_KEYCHAIN_SETTINGS_VERS1;
		oss = SecKeychainCopySettings(keychain, &settings);
		if (oss != 0)
			NSLog(@"SecKeychainCopySettings (%d)", oss);
		settings.version = SEC_KEYCHAIN_SETTINGS_VERS1;
		settings.lockOnSleep = NO;
		settings.useLockInterval = NO;
		settings.lockInterval = INT_MAX;
		SecKeychainSetSettings(keychain, &settings);
		if (oss != 0)
			NSLog(@"SecKeychainSetSettings (%d)", oss);
		oss = SecKeychainCopySettings(keychain, &settings);
	}
#endif
	// non-null keychain?
	if (keychain == 0) {
		NSLog(@"Strange: keychain ref is zero");
		return NO;
	}
	
	NSLog(@"Keychain opened successfully");
	keychain_ = keychain;
	return YES;
}


- (void)closeBanking
{
	// HBCI runterfahren
	if (provider_) {
#ifdef AQBANKING4
		AB_Provider_Fini(provider_, 0);
#else
		AB_Provider_Fini(provider_);
#endif
		provider_ = nil;
	}
	
	// Banking runterfahren
	if (ab_) {
		AB_Banking_Fini(ab_);
		AB_Banking_free(ab_);
		ab_ = nil;
	}
	
	[bankingGeoeffnetFuer_ release];
	bankingGeoeffnetFuer_ = nil;
}

// FIXME: Banken mit Sonderwuenschen
#define ID_NIBC @"51210700" // NIBCdirect
#define ID_CORTAL @"76030080" // Cortal Consors
#define ID_DRESDNER @"https://hbci.dresdner-bank.de" // Dresdner Bank
#define ID_APO @"https://hbcibanking.apobank.de/fints_pintan/receiver" // Apobank

- (BOOL)doppelteAnmeldungenVermeiden:(Konto *)konto
{
	if ([[konto server] rangeOfString:ID_DRESDNER].location != NSNotFound) {
		// Dresdner-Bank mag keine doppelte Anmeldung, also insbesondere keine
		// SystemId + Kontoauszug. Darum merken wir uns die Konfig.
		return YES;
	}
	
	return NO;
}

- (BOOL)useBase64:(Konto *)konto
{
	/*if ([[konto server] rangeOfString:ID_APO].location != NSNotFound) {
		// Apobank -> kein base64
		return NO;
	}*/
	
	return YES;
}

- (BOOL)useSSL3:(Konto *)konto {
	if ([[konto bankleitzahl] isEqualToString:ID_NIBC] || 
	    [[konto bankleitzahl] isEqualToString:ID_CORTAL]) {
		return YES;
	}
	
	return NO;
}


- (BOOL)useHTTP10:(Konto *)konto {
	/*if ([[konto bankleitzahl] isEqualToString:ID_NIBC] || 
	    [[konto bankleitzahl] isEqualToString:ID_CORTAL]) {
		return YES;
	}*/
	
	return NO;
}


- (BOOL)useTanMethodsByProvider:(Konto *)konto {
	if ([[konto bankleitzahl] isEqualToString:ID_NIBC] || 
	    [[konto bankleitzahl] isEqualToString:ID_CORTAL]) {
		return YES;
	}
	
	return NO;
}


- (BOOL)openBankingFuerKonto:(Konto *)konto
{
	// schon offen?
	if (bankingGeoeffnetFuer_ && [bankingGeoeffnetFuer_ isEqualToString:[konto guid]]) {
		NSLog(@"AqBanking schon initialisiert fuer Konto %@.", [konto guid]);
		return YES;
	}
	[self closeBanking];
	bankingGeoeffnetFuer_ = [[konto guid] copy];
	
	// Spezielle Bankbehandlung, bei der die Konfig nicht geloescht wird?
	// Etwa, damit die SystemId nicht immer neugeholt werden muss.
	//BOOL configLoeschen = ![self doppelteAnmeldungenVermeiden:konto];
	
	// Konfigurationsverzeichnis
	NSString * dpath;
	dpath = [NSHomeDirectory() stringByAppendingPathComponent:
		 [NSString stringWithFormat:AQ_CONFIG_PATH, CONFIG_POSTFIX]];
	
	// in Verzeichnis packen?
	NSFileManager * fm = [NSFileManager defaultManager];
	//if ([konto guid] && [[konto guid] length] > 0 && !configLoeschen) {
	if ([konto guid] && [[konto guid] length] > 0) {
		dpath = [dpath stringByAppendingPathComponent:[konto guid]];
		if ([fm fileExistsAtPath:dpath] == NO) {
			NSLog(@"Erstelle Konfigurationsverzeichnis %@", dpath);
			[fm createDirectoryAtPath:dpath
		      withIntermediateDirectories:YES
				       attributes:nil
					    error:nil];
		}
	}
	
	// leere settings.conf erstellen, damit keine Warnung kommt
	NSString * fname = [dpath stringByAppendingPathComponent:@"settings"];
	//if ([fm fileExistsAtPath:fname] == NO || configLoeschen) {
	if ([fm fileExistsAtPath:fname] == NO) {
		NSLog(@"Loesche Konfiguration %@", fname);
		[fm removeItemAtPath:fname error:nil];
	}
	
	// init AqBanking
	NSLog(@"Verwende %@ als Konfiguration.", fname);
	ab_ = AB_Banking_new("hbcitool", [dpath fileSystemRepresentation], 0);
	int rv = AB_Banking_Init(ab_);
	if (rv) {
		fprintf(stderr, "Error on AB_Banking_init (%d)\n", rv);
		[self closeBanking];
		return NO;
	}
	
	// Plugins laden
#if defined(AQBANKING4) || defined(AQBANKING5)
	//GWEN_Plugins_Init();
#else
	AB_Plugins_Init();
#endif

	// Banking-Init
#ifdef AQBANKING4
	rv = AB_Banking_OnlineInit(ab_, 0);
#else
	rv = AB_Banking_OnlineInit(ab_);
#endif
	if (rv) {
		fprintf(stderr, "Error on AB_Banking_OnlineInit (%d)\n", rv);
		[self closeBanking];
		return NO;
	}
	
	// init HBCI
#if defined(AQBANKING4) || defined(AQBANKING5)
	provider_ = (struct AB_PROVIDER *)AB_Banking_GetProvider(ab_, "AQHBCI");
#else
	provider_ = (struct AB_PROVIDER *)AB_Banking_GetProvider(ab_, "aqhbci");
#endif
	if (!provider_) {
		fprintf(stderr, "Could not create HBCI provider object\n");
		[self closeBanking];
		return NO;
	}

	// FIXME: Version
	const char * s = AH_Provider_GetProductVersion(provider_);
	if (s) {
		NSString * version = [NSString stringWithCString:s encoding:NSISOLatin1StringEncoding];
		printf("aqhbci version %s\n", [version UTF8String]);
	}
	
#ifdef AQBANKING3
	// Das hier geht nicht bei Aqb 4, weil AH_Provider_GetHbci assertet
	
	// bigger timeout because 30 sec can be not enough for mobile connections
	// FIXME: we use un-exported functions here.
	void * hbci = (void *)AH_Provider_GetHbci(provider_);
	if (!hbci) {
		fprintf(stderr, "Could not get HBCI object\n");
		[self closeBanking];
		return NO;
	}
	AH_HBCI_SetTransferTimeout(hbci, TRANSFERTIMEOUT);
	AH_HBCI_SetConnectTimeout(hbci, CONNECTTIMEOUT);
#endif

	// Log-Meldungen einstellen
#ifdef DEBUG
	//	GWEN_LOGGER_LEVEL lvl = GWEN_LoggerLevel_Verbous;
	//	GWEN_LOGGER_LEVEL lvl = GWEN_LoggerLevel_Info;
	GWEN_LOGGER_LEVEL lvl = GWEN_LoggerLevel_Info;
#else
	GWEN_LOGGER_LEVEL lvl = GWEN_LoggerLevel_Warning;
#endif
	GWEN_Logger_SetLevel(0, lvl);
	GWEN_Logger_SetLevel("aqhbci", lvl);
	GWEN_Logger_SetLevel("aqbanking", lvl);
	
	return YES;
}


- (void)dealloc
{
	[self closeBanking];
	[delegate_ release];
	
#if defined(AQBANKING4) || defined(AQBANKING5)
	GWEN_Fini();
#endif
	[super dealloc];
}


- (void)awakeFromNib
{
	printf("hbcitool version %s\n", [[Version version] UTF8String]);
	
	ok_ = false; // assume we do not manage to go through the initialisation
	ab_ = nil;
	provider_ = nil;
	delegate_ = nil;
	
	// create distributed object connection for the pref pane
	connection_ = [NSConnection defaultConnection];
	if (!connection_) {
		NSLog(@"Cannot create NSConnection");
		return;
	}
	[connection_ setRootObject:self];
	NSString * machName;
#ifdef DEBUG
	NSArray * args = [[NSProcessInfo processInfo] arguments];
	if ([args indexOfObject:@"--debug"] != NSNotFound)
		machName = @"com.limoia.hbcitool";
	else
#endif
	machName = [NSString stringWithFormat:@"com.limoia.hbcitool-%d-%d",
			    getppid(),
			    [[NSProcessInfo processInfo] processIdentifier]];
	if ([connection_ registerName:machName] == NO) {
		fprintf(stderr, "Cannot create CocoaBanking connection\n");
		return;
	}
	
	// open Keychain
	[self openKeychain];
	
	NSLog(@"hbcitool initialisation successful");
	ok_ = YES;
}


- (void)log:(NSString *)s
{
	if (delegate_)
		[delegate_ log:s];
	else
		NSLog(s);
}


- (out BOOL)isValid
{
	return ok_;
}


- (void)setDelegate:(NSObject<CocoaBankingDelegate> *)delegate
{
	[delegate_ autorelease];
	delegate_ = [delegate retain];
}


- (NSObject<CocoaBankingDelegate> *)delegate
{
	return delegate_;
}


- (NSString *)kontonummerForKonto:(Konto *)konto
{
	if ([konto unterkonto] == nil 
	    || [[konto unterkonto] kontonummer] == nil) // || [[[konto unterkonto] bankleitzahl] length] == 0)
		return [konto kennung];
	else
		return [[konto unterkonto] kontonummer];
}


- (NSString *)bankleitzahlForKonto:(Konto *)konto
{
	if ([konto unterkonto] == nil 
	    || [[konto unterkonto] bankleitzahl] == nil) // || [[[konto unterkonto] bankleitzahl] length] == 0)
		return [konto bankleitzahl];
	else
		return [[konto unterkonto] bankleitzahl];
}


- (AB_USER *)createUser:(Konto *)konto
{
	// wir merken uns das fuer die globalen Funktionen
	[gui_ setCurrentKonto:konto];
	//NSLog(@"Using the konto\n%@", [konto convertToDictionary]);

	NSString * userId = [konto benutzerId];
	if (userId == nil || [userId length] == 0)
		userId = [konto kennung];
	NSString * customerId = [konto kundenId];
	if (customerId == nil || [customerId length] == 0)
		customerId = userId;

	// try to find the user and get rid of him
	NSLog(@"Try: Using the user at %@ with server %@", [konto bankleitzahl], [konto server]);
	BOOL neu = NO;
	AB_USER * user = AB_Banking_FindUser(ab_, AH_PROVIDER_NAME, "de",
					     [[konto bankleitzahl] UTF8String],
					     [userId UTF8String],
					     [customerId UTF8String]);
	
	if (!user) {
		[self log:[NSString stringWithFormat:NSLocalizedString(@"Creating user.", nil), [konto bankleitzahl]]];
		neu = YES;
		user = AB_Banking_CreateUser(ab_, AH_PROVIDER_NAME);
		if (!user) {
			[self log:NSLocalizedString(@"Error creating user. Shit!", nil)];
			return 0;
		}
	} else {
		neu = NO;
		//[self log:[NSString stringWithFormat:NSLocalizedString(@"User found. BLZ: %@", nil), [konto bankleitzahl]]];
		//[self log:[NSString stringWithFormat:NSLocalizedString(@"Using HBCI-Version %d", nil), AH_User_GetHbciVersion(user)]];
		//return user;
	}

	// Standard-Werte setzen
	AB_User_SetBankCode(user, [[konto bankleitzahl] UTF8String]);
	AB_User_SetUserId(user, [userId UTF8String]);
	AB_User_SetCustomerId(user, [customerId UTF8String]);
	AB_User_SetUserName(user, "hbcitool");
	AB_User_SetCountry(user, "de");
	AH_User_SetTokenType(user, "pintan");
	AH_User_SetTokenName(user, 0);
	AH_User_SetTokenContextId(user, 0);
	AH_User_SetCryptMode(user, AH_CryptMode_Pintan);
#if defined(AQBANKING4) || defined(AQBANKING5)
	AH_User_AddFlags(user, AH_USER_FLAGS_KEEPALIVE);
#endif

	// setup connection settings
	AH_User_SetHbciVersion(user, [[konto hbciVersion] intValue]);
	[self log:[NSString stringWithFormat:NSLocalizedString(@"Using HBCI-Version %d", nil), AH_User_GetHbciVersion(user)]];
	/*if ([[konto SSL3] boolValue]) {
		[self log:@"Forcing SSL3"];
		AH_User_AddFlags(user, AH_USER_FLAGS_FORCE_SSL3);
	} else {
		[self log:@"Without SSL3"];
		AH_User_SubFlags(user, AH_USER_FLAGS_FORCE_SSL3);
	}*/
	
	// SSL3 setzen?
	if ([self useSSL3:konto]) {
		[self log:NSLocalizedString(@"Forcing SSL3 for bank",nil)];
		AH_User_AddFlags(user, AH_USER_FLAGS_FORCE_SSL3);
	} else {
		if ([[konto SSL3] boolValue]) {
			[self log:NSLocalizedString(@"Forcing SSL3",nil)];
			AH_User_AddFlags(user, AH_USER_FLAGS_FORCE_SSL3);
		} else {
			[self log:NSLocalizedString(@"Without SSL3",nil)];
			AH_User_SubFlags(user, AH_USER_FLAGS_FORCE_SSL3);
		}
	}
	
	// FIXME: HTTP-Version 1.0 setzen
	if ([self useHTTP10:konto]) {
		[self log:NSLocalizedString(@"Using HTTP v1.0 for Bank", nil)];
		AH_User_SetHttpVMajor(user, 1);
		AH_User_SetHttpVMinor(user, 0);
	}
	
	// kein base64? -> Apobank
	if (![self useBase64:konto]) {
		[self log:NSLocalizedString(@"Apobank: No base64", nil)];
		AH_User_AddFlags(user, AH_USER_FLAGS_NO_BASE64);
	} else {
		AH_User_SubFlags(user, AH_USER_FLAGS_NO_BASE64);
	}
	
	// set server url
	if ([konto server] == nil) {
		[self log:NSLocalizedString(@"No HBCI-Server given.", nil)];
		return 0;
	}
	GWEN_URL * url = GWEN_Url_fromString([[konto server] UTF8String]);
	GWEN_Url_SetProtocol(url, "https");
	if (GWEN_Url_GetPort(url)==0)
		GWEN_Url_SetPort(url, 443);
	AH_User_SetServerUrl(user, url);
	GWEN_Url_free(url);
	
	// create user
	if (neu) {
		AB_Banking_AddUser(ab_, user);

		// check that it worked
		user = AB_Banking_FindUser(ab_, AH_PROVIDER_NAME, "de",
				   [[konto bankleitzahl] UTF8String],
				   [userId UTF8String],
				   [customerId UTF8String]);
		if (!user) {
			[self log:NSLocalizedString(@"User could not be created", nil)];
			return 0;
		}
	}
	
	return user;
}


- (NSError *)error:(NSString *)desc
{
	NSDictionary * details = 
	[NSMutableDictionary dictionaryWithObject:NSLocalizedString(desc, nil)
					   forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:@"CocoaBanking" code:1 userInfo:details];
}


- (NSDictionary *)hbciFehlerInLog:(NSArray *)log
{
	// HBCI: 9800 - Dialog abgebrochen (HBMSG=10321) (M)
	NSMutableDictionary * ret = [NSMutableDictionary dictionary];
	
	// Prefix
	NSString * prefix = @"HBCI: ";
	NSRange prefixR;
	prefixR.location = 0;
	prefixR.length = [prefix length];
	
	// Fehlernummer
	NSRange nummerR;
	nummerR.location = 6;
	nummerR.length = 4;
	
	for (NSString * s in log) {
		if ([[s substringWithRange:prefixR] compare:prefix] == 0) {
			NSString * nummer = [s substringWithRange:nummerR];
			NSString * text = [s substringFromIndex:13];
			[ret setObject:text forKey:nummer];
			NSLog(@"HBCI-Fehler %@: %@", nummer, text);
		}
	}
	
	return ret;
}


- (NSError *)doppelAnmeldungsFehler:(NSArray *)log
{
	NSDictionary * fehler = [self hbciFehlerInLog:log];
	NSString * ret = @"";
	NSString * text;
	
	// 9210 - Benutzer fuehrt bereits aktiven Dialog - Doppelanmeldung 
	// Meldet etwa die Dresdner Bank gerne
	if ((text = [fehler objectForKey:@"9210"]) 
	    && [text rangeOfString:@"Doppel"].location != NSNotFound)
		ret = [NSString stringWithFormat:@"%@ - %@", text, @"Warten Sie bitte 20 Minuten."];
	
	// War einer dabei?
	if ([ret length] == 0)
		return nil;
	else
		return [self error:ret];
}


- (NSError *)pinFehler:(NSArray *)log 
{
	NSDictionary * fehler = [self hbciFehlerInLog:log];
	NSString * ret = @"";
	NSString * text;
	
	// die 3 PIN-Fehler suchen
	if (text = [fehler objectForKey:@"9942"])
	    ret = [NSString stringWithFormat:@"%@ %@;", ret, text];
	if (text = [fehler objectForKey:@"9932"])
	    ret = [NSString stringWithFormat:@"%@ %@;", ret, text];
	if (text = [fehler objectForKey:@"9931"])
	    ret = [NSString stringWithFormat:@"%@ %@;", ret, text];
	
	// War einer dabei?
	if ([ret length] == 0)
	    return nil;
	else {
		// ; entfernen am Ende
		if ([ret characterAtIndex:[ret length] - 1] == ';')
			ret = [ret substringToIndex:[ret length] - 1];

		// Fehler melden
		return [self error:ret];
	}
}


- (void)deleteFromKeychain:(Konto *)konto
{
	if (keychain_ == 0) {
		NSLog(@"Cannot delete keychain entries for account "
		      "because the keychain is not available.");
		return;
	}
	
	// Find entry
	const char * password;
        UInt32 passwordLength;
        SecKeychainItemRef item = NULL;
	NSString * account = [gui_ keychainAccount:konto];
	NSString * service = [gui_ keychainService:konto];
	OSStatus result = SecKeychainFindGenericPassword(
							 keychain_,
							 [service length],
							 [service UTF8String],
							 [account length],
							 [account UTF8String],
							 &passwordLength,
							 (void **) &password,
							 &item
							 );
	if (result == 0) {
		[delegate_ log:
		 [NSString stringWithFormat:NSLocalizedString(@"Deleting PIN from keychain for account %@ at bank %@.", nil),
		  [konto kennung], [konto bankleitzahl]]];
		SecKeychainItemDelete(item);
	}
}


- (NSError *)getSysId:(AB_USER *)user andKonto:(Konto *)konto
{
	// Protokollversion ausgeben
	[self log:[NSString stringWithFormat:NSLocalizedString(@"Selected protocol version: %d", nil), [[konto hbciVersion] intValue]]];
	
	// GetSysId
	[gui_ setCanceled:NO];
	[gui_ startLog];
	AB_IMEXPORTER_CONTEXT * ctx = AB_ImExporterContext_new();
	
#if defined(AQBANKING5)
	// certs holen
	//AH_Provider_GetCert(provider_, user, 0, 0, 1);
	
	// SystemId holen
	int rv = AH_Provider_GetSysId(provider_, user, ctx, 0, 0, 1);
	
	// iTanModes holen
	if ([self useTanMethodsByProvider:konto]) {
		// TanModes holen
		int noTanModes = AH_Provider_GetItanModes(provider_, user, ctx, 0, 0, 1);
		if (noTanModes) {
			[self log:NSLocalizedString(@"Couldn't get Tan Modes from Provider", nil)];
		}
	}
#else
	int rv = AH_Provider_GetSysId(provider_, user, ctx, 0, 0);
#endif
	
	AB_ImExporterContext_free(ctx);
	
	// Pin-Fehler?
	NSError * pinFehler = [self pinFehler:[gui_ stopLog]];
	if (pinFehler) {
		[self deleteFromKeychain:konto];
		return pinFehler;
	}

	// doppelte Anmeldung (etwa mit Dresdner Bank)
	NSError * doppelAnmeldungsFehler = [self doppelAnmeldungsFehler:[gui_ stopLog]];
	if (doppelAnmeldungsFehler)
		return doppelAnmeldungsFehler;
	
	// PIN abgebrochen?
	if ([gui_ canceled])
		return [self error:NSLocalizedString(@"Entry of PIN was canceled.", nil)];
	
	// Anderer Fehler?
	if (rv) {
		[self log:[NSString stringWithFormat:NSLocalizedString(@"Error getting system id (%d)", nil), rv]];
		
		// SSL3-Flag umdrehen
#if defined(AQBANKING5)
		AB_Banking_BeginExclUseUser(ab_, user);
#else
		AB_Banking_BeginExclUseUser(ab_, user, 0);
#endif
		
		BOOL ssl3 = ![[konto SSL3] boolValue];
		[self log:[NSString stringWithFormat:@"\n%@", 
			   [NSString stringWithFormat:NSLocalizedString(@"We try again with ForceSSL3 = %d", nil), ssl3]]];
		if (ssl3) {
			[self log:NSLocalizedString(@"Forcing SSL3",nil)];
			AH_User_AddFlags(user, AH_USER_FLAGS_FORCE_SSL3);
		} else {
			[self log:NSLocalizedString(@"Without SSL3",nil)];
			AH_User_SubFlags(user, AH_USER_FLAGS_FORCE_SSL3);
		}
		
#if defined(AQBANKING5)
		AB_Banking_EndExclUseUser(ab_, user, 0);
#else
		AB_Banking_EndExclUseUser(ab_, user, 0, 0);
#endif
		
		// nochmal probieren
		[gui_ startLog];
		ctx = AB_ImExporterContext_new();
#if defined(AQBANKING5)
		rv = AH_Provider_GetSysId(provider_, user, ctx, 0, 0, 1);
#else
		rv = AH_Provider_GetSysId(provider_, user, ctx, 0, 0);
#endif
		AB_ImExporterContext_free(ctx);
		pinFehler = [self pinFehler:[gui_ stopLog]];
		
		// Pin-Fehler?
		if (pinFehler) {
			[self deleteFromKeychain:konto];
			return pinFehler;
		}
		
		// Anderer Fehler?
		if (rv) {
			[self log:[NSString stringWithFormat:NSLocalizedString(@"Error getting system id (%d)", nil), rv]];
			return [self error:NSLocalizedString(@"Connection to server failed. Look into the protocol for more information.", nil)];
		}
		
		// SSL3-Flag hat geholfen. Also speichern wir es.
		[konto setSSL3:[NSNumber numberWithBool:ssl3]];
	}
	[self log:NSLocalizedString(@"getsysid finished", nil)];
	
	return nil;
}


- (void)terminate
{
	NSLog(@"Shutting down");
	[self closeBanking];
	[NSApp terminate:self];
}


- (void)setStandardTanMethod:(AB_USER *) user {
	// Standard TAN-Method = erste TAN-Methode auf der "echten" TAN-Method-Liste, ausser 999, wenn es geht.
	int tmlCount = AH_User_GetTanMethodCount(user);
		
	const int * tml = AH_User_GetTanMethodList(user);
	int firstTm = 0;
	
	if (tmlCount == 1) {
		firstTm = tml[0];
		NSLog(@"Nur eine TAN-Methode vorhanden.");
	} else {
		int n = tmlCount;
		NSLog(@"Es gibt mehr als eine TAN-Methode.");
		while (n>0) {
			if (tml[n-1] != 999) {
				firstTm = tml[n-1];
				break;
			}
			n = n - 1;
		}
	}
	[self log:[NSString stringWithFormat:NSLocalizedString(@"Setting Standard TAN Method (%d)", nil), firstTm]];
	
	// Standard TAN-Methode setzen
	if (AB_Banking_BeginExclUseUser(ab_, user) == 0) {
		AH_User_SetSelectedTanMethod(user, firstTm);
		AB_Banking_EndExclUseUser(ab_, user, NO);
	}
}



- (NSError *)setTanMethodOfKonto:(Konto *)konto forUser:(AB_USER *)user
{
	// Wenn keine Tan-Methode gesetzt, standard verwenden.
	//if (method == nil) {
	BOOL useStandardTm = YES;
	if ([konto tanMethode] == nil) {
		[self log:NSLocalizedString(@"Using standard TAN method.", nil)];
		//AH_User_SetSelectedTanMethod(user, 0);
		//return nil;
	} else {
		if ([[[konto tanMethode] funktion] intValue] == -1) {
			[self log:NSLocalizedString(@"Please change Tan Method. We using standard TAN method.", nil)];
			
		} else {
			useStandardTm = NO;
			NSLog(@"Found stored TAN method in Konto.");
		}
	}

	
	// TanMethods auslesen
	const AH_TAN_METHOD_LIST * allTmForBank = AH_User_GetTanMethodDescriptions(user);
	if (!allTmForBank) {
		[self log:NSLocalizedString(@"No TAN methods available. Try to connect to bank first.", nil)];
		return nil;
	}
	AH_TAN_METHOD * tm;
	tm=AH_TanMethod_List_First(allTmForBank);
	int methodNum = 0;
	
	// Setze Standard TanMethode
	if (useStandardTm) {
		[self setStandardTanMethod:user];
		return nil;
	}
	
	// Method suchen
	while (tm) {
		int func = AH_TanMethod_GetFunction(tm);
		if (func) {
			if ([[[konto tanMethode] funktion] intValue] == func) {
				NSLog(NSLocalizedString(@"Found selected TAN method: %@", nil), [[konto tanMethode] bezeichnung]);
				break;
			}
		}
		tm = AH_TanMethod_List_Next(tm);
		methodNum++;
	}
	
	// nicht gefunden?
	if (tm == NULL) {
		NSString * msg = [NSString stringWithFormat:
				 NSLocalizedString(@"Selected TAN method '%@' not found. Trying standard TAN method...", nil),
				 [[konto tanMethode] bezeichnung]];
		[self log:msg];
		
		// Setze Standard TanMethode
		[self setStandardTanMethod:user];
		return nil;
	} else {
		// eine gefunden
		const char * s = AH_TanMethod_GetMethodName(tm);
		NSString * name = NSLocalizedString(@"Unknown", nil);
		if (s) {
			name = [NSString stringWithCString:s encoding:NSISOLatin1StringEncoding];
		}
		int i = AH_TanMethod_GetFunction(tm);
		NSLog(NSLocalizedString(@"Setting %d. TAN method %d \"%@\"", nil), methodNum + 1, i, name);
		[self log:[NSString stringWithFormat:NSLocalizedString(@"Using TAN method '%@'", nil), [[konto tanMethode] bezeichnung]]];
		NSLog(@"Old TAN method %d", AH_User_GetSelectedTanMethod(user));
		
		// TAN-Methode setzen
		if (AB_Banking_BeginExclUseUser(ab_, user) == 0) {
			AH_User_SetSelectedTanMethod(user, i);
			AB_Banking_EndExclUseUser(ab_, user, NO);
		}
	}
	
	return nil;
}


- (NSArray *)getTanMethods:(Konto *)konto error:(NSError **)error
{
	if (!ok_) {
		[self log:NSLocalizedString(@"CocoaBanking is not valid", nil)];
		return nil;
	}
	
	// Banking neu oeffnen
	ok_ = [self openBankingFuerKonto:konto];
	if (!ok_) {
		[self log:NSLocalizedString(@"AqBanking init error.", nil)];
		return nil;
	}

	// Benutzer erstellen
	AB_USER * user = [self createUser:konto];
	if (!user) {
		[self log:NSLocalizedString(@"hbcitool could not create the user entry.", nil)];
		return nil;
	}
	
	// getsysid aufrufen
	if (AH_User_GetSystemId(user) == NULL) {
		*error = [self getSysId:user andKonto:konto];
		if (*error) {
			NSLog(@"hbcitool could not successfully send getSysId to bank.");
			return nil;
		}
		
		// settings.conf speichern
#if defined(AQBANKING5)
		AB_Banking_SaveConfig(ab_);
#elif defined(AQBANKING4)
		AB_Banking_SaveConfig(ab_, 0);
#else
		AB_Banking_Save(ab_);
#endif
		
		if ([self doppelteAnmeldungenVermeiden:konto]) {
			[self log:NSLocalizedString(@"Waiting 5 seconds to keep some servers happy", nil)];
			sleep(5);
		} else
			sleep(1);
	}
	
	// iTanModes holen
	AB_IMEXPORTER_CONTEXT * ctx = AB_ImExporterContext_new();
	int noTanModes = AH_Provider_GetItanModes(provider_, user, ctx, 0, 0, 1);
	if (noTanModes) {
		[self log:NSLocalizedString(@"Couldn't get Tan Modes from Provider", nil)];
	}
	
	// TanMethods auslesen
	NSMutableArray * ret = [[NSMutableArray new] autorelease];
	const AH_TAN_METHOD_LIST * tmlForBank = AH_User_GetTanMethodDescriptions(user); // Alle von der Bank unterstuetzten TAN-Methoden
	
	if (!tmlForBank) {
		[self log:NSLocalizedString(@"No TAN methods available. Try to connect to bank first.", nil)];
		return nil;
	}
	
	AH_TAN_METHOD *tm;
	tm=AH_TanMethod_List_First(tmlForBank);
	if (tm) {
		// Fuer Debugzwecke Ausgabe der echten TAN-Liste
		int tmlForUserCount = AH_User_GetTanMethodCount(user);
		const int * tmlForUser = AH_User_GetTanMethodList(user); // Die Tan-Methoden, die auch funktionieren
		NSString * tmString = @"";
		BOOL first = YES;
		while (tmlForUserCount>0) {
			NSString * s;
			if (first) {
				s = [NSString stringWithFormat:@" %d", tmlForUser[tmlForUserCount-1]];
			} else {
				s = [NSString stringWithFormat:@", %d", tmlForUser[tmlForUserCount-1]];
			}
			tmString = [tmString stringByAppendingString:s];
			first = NO;
			tmlForUserCount = tmlForUserCount - 1;
		}
		[self log:[NSString stringWithFormat:NSLocalizedString(@"Possible TAN Methods: %@", nil), tmString]];
		
#ifdef TAN_DEBUG
		[self log:@"(1) tmlBank -> tmlUser:"];
#endif
		while (tm) {
			// Ist die Tan-Methode Teil der TanMethodList? (= funktionierende TAN-Methode)
			tmlForUserCount = AH_User_GetTanMethodCount(user);
			int tmFunction = AH_TanMethod_GetFunction(tm);
			//const int * tml = AH_User_GetTanMethodList(user); // Die Tan-Methoden, die auch funktionieren
			BOOL foundTm = NO; 
			while (tmlForUserCount > 0) {
				if (tmFunction == tmlForUser[tmlForUserCount-1]) {
					foundTm = YES;
#ifdef TAN_DEBUG
					[self log:[NSString stringWithFormat:@"%d Y", tmFunction]];
#endif
					break;
				}
				tmlForUserCount = tmlForUserCount - 1;
			}
#ifdef TAN_DEBUG
			if (foundTm==NO) {
				[self log:[NSString stringWithFormat:@"%d N", tmFunction]];
			}
#endif
			
			// Tan-Methode aufnehmen
			if (foundTm) {
				const char * sId = AH_TanMethod_GetMethodId(tm);
				const char * sName = AH_TanMethod_GetMethodName(tm);
				if (sId) {
					int func = AH_TanMethod_GetFunction(tm);
					NSNumber * tanMethodFunktion = [NSNumber numberWithInt:func];
					NSString * tanMethodId = [NSString stringWithCString:sId encoding:NSISOLatin1StringEncoding];
					NSString * tanMethodName = [NSString stringWithCString:sName encoding:NSISOLatin1StringEncoding];
					
					NSDictionary * tanMethod = [NSDictionary dictionaryWithObjectsAndKeys:
								    tanMethodFunktion, @"funktion",
								    tanMethodId, @"id_name",
								    tanMethodName, @"name", nil];
#ifdef TAN_DEBUG
					[self log:[NSString stringWithFormat:@"ADD %d", [[tanMethod objectForKey:@"funktion"] intValue]]];
#endif
					[ret addObject:tanMethod];
				}
			}

			tm = AH_TanMethod_List_Next(tm);                                                                                  
		}
	} else {
		[self log:NSLocalizedString(@"Could not found possible TAN Methods.",nil)];
	}
	
#ifdef TAN_DEBUG
	[self log:@"(2) HT: "];
	for (NSDictionary * t in ret) {
		[self log:[NSString stringWithFormat:@"%d", [[t objectForKey:@"funktion"] intValue]]];
	}
	[self log:@"."];
#endif
	
	return ret;
}


- (NSArray *)getSubAccounts:(Konto *)konto error:(NSError **)error
{
	if (!ok_) {
		[self log:NSLocalizedString(@"CocoaBanking is not valid", nil)];
		*error = [self error:NSLocalizedString(@"hbcitool is in an invalid state.", nil)];
		return nil;
	}
	
	// Banking neu oeffnen
	ok_ = [self openBankingFuerKonto:konto];
	if (!ok_) {
		*error = [self error:NSLocalizedString(@"AqBanking init error.", nil)];
		return nil;
	}

	// Benutzer erstellen
	AB_USER * user = [self createUser:konto];
	if (!user) {
		*error = [self error:NSLocalizedString(@"hbcitool could not create the user entry.", nil)];
		return nil;
	}
	
	// getsysid aufrufen
	if (AH_User_GetSystemId(user) == NULL) {
		*error = [self getSysId:user andKonto:konto];
		if (*error) {
			NSLog(@"hbcitool could not successfully send getSysId to bank.");
			return nil;
		}
		
		// settings.conf speichern
#if defined(AQBANKING5)
		AB_Banking_SaveConfig(ab_);
#elif defined(AQBANKING4)
		AB_Banking_SaveConfig(ab_, 0);
#else
		AB_Banking_Save(ab_);
#endif

		if ([self doppelteAnmeldungenVermeiden:konto]) {
			[self log:NSLocalizedString(@"Waiting 5 seconds to keep some servers happy", nil)];
			sleep(5);
		} else
			sleep(1);
	}

	// TAN-Methode setzen
/*	*error = [self setTanMethodOfKonto:konto forUser:user];
	if (*error)
		return nil;*/
		
	// Accounts abfragen
	AB_IMEXPORTER_CONTEXT * ctx = AB_ImExporterContext_new();
#if defined(AQBANKING5)
	int rv = AH_Provider_GetAccounts(provider_, user, ctx, 0, 0, 0);
#else
	int rv = AH_Provider_GetAccounts(provider_, user, ctx, 0, 0);
#endif
	if (rv) {
		// doppelte Anmeldung (etwa Dresdner Bank)
		NSError * doppelAnmeldungsFehler = [self doppelAnmeldungsFehler:[gui_ stopLog]];
		if (doppelAnmeldungsFehler) {
			*error = doppelAnmeldungsFehler;
			return nil;
		}
		
		[self log:[NSString localizedStringWithFormat:NSLocalizedString(@"Error getting hbci accounts (%d)", nil), rv]];
		*error = [self error:NSLocalizedString(@"hbcitool could not get the HBCI accounts.", nil)];
		return nil;
	}
	
	// Accounts sammeln
	NSMutableArray * ret = [[NSMutableArray new] autorelease];
	AB_ACCOUNT_LIST2 * al;
	al = AB_Banking_FindAccounts(ab_, AH_PROVIDER_NAME, "de", "*", "*", "*");
	if (al) {
		AB_ACCOUNT_LIST2_ITERATOR * ait;
		ait = AB_Account_List2_First(al);
		if (ait) {
			AB_ACCOUNT *a;
			int i=0;
			
			a = AB_Account_List2Iterator_Data(ait);
			assert(a);
			while(a) {
				[self log:[NSString localizedStringWithFormat:NSLocalizedString(@"Account %d: Bank: %s Account Number: %s\n", nil),
					i++,
					AB_Account_GetBankCode(a),
					AB_Account_GetAccountNumber(a)]];
				const char * name = AB_Account_GetAccountName(a);
				const char * kontonummer = AB_Account_GetAccountNumber(a);
				const char * bankleitzahl = AB_Account_GetBankCode(a);
				
				NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:
						       kontonummer ? [NSString stringWithUTF8String:kontonummer] : nil, @"kontonummer",
						       name ? [NSString stringWithUTF8String:name] : nil, @"name",
						       bankleitzahl ? [NSString stringWithUTF8String:bankleitzahl] : nil, @"bankleitzahl",
						       nil];
				NSLog(@"Found account: %@", dict);
				[ret addObject:dict];
				a = AB_Account_List2Iterator_Next(ait);
			}
			AB_Account_List2Iterator_free(ait);
		}
		AB_Account_List2_free(al);
	}
	
	*error = nil;
	return ret;
}


- (NSString *)foldStringList:(const GWEN_STRINGLIST *)sl withSep:(NSString *)sep
{
	NSString * ret = nil;
	if (sl) {
		int n = GWEN_StringList_Count(sl);
		int i;
		BOOL first = YES; 
		for (i = 0; i < n; ++i) {
			const char * cs = GWEN_StringList_StringAt(sl, i);
			if (cs && strlen(cs) > 0) {
				NSString * s = [NSString stringWithUTF8String:cs];
				if (first)
					ret = s;
				else
				ret = [NSString stringWithFormat:@"%@%@%@", ret, sep, s];
				first = NO;
			}
		}
	}
	
	return ret;
}


- (out bycopy NSArray *)getTransactions:(in bycopy Konto *)konto 
				   from:(NSDate *)from
			      balanceTo:(double *)balance
		      balanceCurrencyTo:(NSString **)balanceCurrency
				  error:(NSError **)error
{
	if (!ok_) {
		[self log:NSLocalizedString(@"CocoaBanking is not valid", nil)];
		*error = [self error:NSLocalizedString(@"hbcitool is in an invalid state.", nil)];
		return nil;
	}
	
	// Banking neu oeffnen
	ok_ = [self openBankingFuerKonto:konto];
	if (!ok_) {
		*error = [self error:NSLocalizedString(@"AqBanking init error.", nil)];
		return nil;
	}
	
	// Pruefen, dass alles da ist
	if ([konto server] == nil || [[konto server] length] == 0) {
		*error = [self error:NSLocalizedString(@"No HBCI server entered.", nil)];
		return nil;
	}
	NSString * knr = [self kontonummerForKonto:konto];
	if (knr == nil || [knr length] == 0) {
		*error = [self error:NSLocalizedString(@"No account number entered.", nil)];
		return nil;
	}
	NSString * blz = [self bankleitzahlForKonto:konto];
	if (blz == nil || [blz length] == 0) {
		*error = [self error:NSLocalizedString(@"No bank number entered.", nil)];
		return nil;
	}

	// Benutzer erstellen
	AB_USER * user = [self createUser:konto];
	if (!user) {
		*error = [self error:NSLocalizedString(@"hbcitool could not create the user entry.", nil)];
		return nil;
	}
	
	// getsysid aufrufen
	NSLog(@"Old systemId = %s", AH_User_GetSystemId(user));
	if (AH_User_GetSystemId(user) == NULL) {
		*error = [self getSysId:user andKonto:konto];
		if (*error) {
			NSLog(@"hbcitool could not successfully send getSysId to bank.");
			return nil;
		}
		
		// settings.conf speichern
		NSLog(@"New systemId = %s", AH_User_GetSystemId(user));

#if defined(AQBANKING5)
		AB_Banking_SaveConfig(ab_);
#elif defined(AQBANKING4)
		AB_Banking_SaveConfig(ab_, 0);
#else
		AB_Banking_Save(ab_);
#endif
		
		if ([self doppelteAnmeldungenVermeiden:konto]) {
			[self log:NSLocalizedString(@"Waiting 5 seconds to keep some servers happy", nil)];
			sleep(5);
		} else
			sleep(1);
	}
	
	// TAN-Methode setzen
	*error = [self setTanMethodOfKonto:konto forUser:user];
	if (*error)
		return nil;

	// Accounts abfragen
	AB_IMEXPORTER_CONTEXT * ctx = AB_ImExporterContext_new();
	int rv;
#if 0
	= AH_Provider_GetAccounts(provider_, user, ctx, 0, 0);
	if (rv) {
		// Manche Banken koennen das wohl nicht. Wir machen mal weiter
		// und schauen, ob ein Konto da ist.
		[self log:[NSString localizedStringWithFormat:NSLocalizedString(@"Error getting hbci accounts (%d)", nil), rv]];
		/* *error = [self error:NSLocalizedString(@"hbcitool could not get the HBCI accounts.", nil)];
		return nil;*/
	}
	
	// Accounts anzeigen
	AB_ACCOUNT_LIST2 * al;
	al = AB_Banking_FindAccounts(ab_, AH_PROVIDER_NAME, "de", "*", "*");
	int num = 0;
	if (al) {
		AB_ACCOUNT_LIST2_ITERATOR * ait;
		ait = AB_Account_List2_First(al);
		if (ait) {
			AB_ACCOUNT * a = AB_Account_List2Iterator_Data(ait);
			while(a) {
				[self log:[NSString localizedStringWithFormat:@"Konto %s:%s %s\n",
					   AB_Account_GetBankCode(a),
					   AB_Account_GetAccountNumber(a),
					   AB_Account_GetAccountName(a)]];
				num++;
				a = AB_Account_List2Iterator_Next(ait);
			}
			AB_Account_List2Iterator_free(ait);
		}
		AB_Account_List2_free(al);
	}
	if (num == 0) {
		[self log:[NSString localizedStringWithFormat:NSLocalizedString(@"No accounts known.", nil), rv]];
	}
	
	// Welchen Account?
	NSString * kontonummer = [self kontonummerForKonto:konto];
	NSString * bankleitzahl = [self bankleitzahlForKonto:konto];
	NSLog(@"Getting transactions");
	AB_ACCOUNT * account = AB_Banking_GetAccountByCodeAndNumber(ab_,
		[bankleitzahl UTF8String], [kontonummer UTF8String]);
	if (!account) {
		[self log:NSLocalizedString(@"Cannot find subaccount. Creating one myself.", nil)];
		if (num > 0) {
			*error = [self error:NSLocalizedString(@"hbcitool could not find subaccount.", nil)];
			return nil;
		}
		
		// Neues Konto manuell erstellen und aufs Beste hoffen
		account = AB_Banking_CreateAccount(ab_, "aqhbci");
		if (!account) {
			*error = [self error:NSLocalizedString(@"Error during account creation.", nil)];
			return nil;
		}
		AB_Account_SetAccountNumber(account, [kontonummer UTF8String]);
		AB_Account_SetBankCode(account, [bankleitzahl UTF8String]);
		AB_Account_SetUser(account, user);
		AB_Account_SetSelectedUser(account, user);
	}
#else
	// Welchen Account?
	NSString * kontonummer = [self kontonummerForKonto:konto];
	NSString * bankleitzahl = [self bankleitzahlForKonto:konto];
	AB_ACCOUNT * account = AB_Banking_GetAccountByCodeAndNumber(ab_,
		[bankleitzahl UTF8String], [kontonummer UTF8String]);
	if (!account) {
		account = AB_Banking_CreateAccount(ab_, "aqhbci");
		if (!account) {
			*error = [self error:NSLocalizedString(@"Error during account creation.", nil)];
			return nil;
		}
		AB_Account_SetAccountNumber(account, [kontonummer UTF8String]);
		AB_Account_SetBankCode(account, [bankleitzahl UTF8String]);
	}
	AB_Account_SetUser(account, user);
	AB_Account_SetSelectedUser(account, user);
#endif
	
	// Transactions-Job
	NSLog(@"Getting transactions");
	AB_JOB_LIST2 *jobList = AB_Job_List2_new();
	AB_JOB * transactionsJob = AB_JobGetTransactions_new(account);	
#if defined(AQBANKING5)
	rv = AB_Job_CheckAvailability(transactionsJob);
#else
	rv = AB_Job_CheckAvailability(transactionsJob, 0);
#endif
	if (rv) {
		[self log:[NSString localizedStringWithFormat:NSLocalizedString(@"Transactions job is not available (%d)", nil), rv]];
		AB_Job_free(transactionsJob);
		transactionsJob = 0;
		//*error = [self error:@"hbcitool 'getTransactions' job is not available."];
		//return nil;

	}
	if (transactionsJob) {
		// Anfangszeit setzen
		NSTimeInterval secondsSince1970 = [from timeIntervalSince1970];
		GWEN_TIME * gwenFrom = GWEN_Time_fromSeconds((uint32_t)secondsSince1970);
		AB_JobGetTransactions_SetFromTime(transactionsJob, gwenFrom);
		GWEN_Time_free(gwenFrom);
		
		AB_Job_List2_PushBack(jobList, transactionsJob);
	}
	
	// Balance-Job
	AB_JOB * balanceJob = 0;
	if (balance != 0) {
		balanceJob = AB_JobGetBalance_new(account);
#if defined(AQBANKING5)
		rv = AB_Job_CheckAvailability(balanceJob);
#else
		rv = AB_Job_CheckAvailability(balanceJob, 0);
#endif
		if (rv) {
			[self log:[NSString localizedStringWithFormat:NSLocalizedString(@"Balance job is not available (%d)", nil), rv]];
			AB_Job_free(balanceJob);
			balanceJob = 0;
		} else
			AB_Job_List2_PushBack(jobList, balanceJob);
	}
	
	// Ein unterstuetzter Job gefunden?
	if (balanceJob == 0 && transactionsJob == 0) {
		fprintf(stderr, "No supported job found. Stopping.\n");
		*error = [self error:NSLocalizedString(@"Neither balance nor transactions is supported by the bank.", nil)];
		AB_Job_List2_FreeAll(jobList);
		return nil;
	}
	
	// Jobs ausfuehren
	ctx = AB_ImExporterContext_new();
#if defined(AQBANKING5)
	rv = AB_Banking_ExecuteJobs(ab_, jobList, ctx);
#else
	rv = AB_Banking_ExecuteJobs(ab_, jobList, ctx, 0);
#endif
	
	if (rv) {
		// doppelte Anmeldung (etwa Dresdner Bank)
		NSError * doppelAnmeldungsFehler = [self doppelAnmeldungsFehler:[gui_ stopLog]];
		if (doppelAnmeldungsFehler) {
			*error = doppelAnmeldungsFehler;
			return nil;
		}
		
		// sysid mal neu laden
		NSString * oldSysId = [NSString stringWithCString:AH_User_GetSystemId(user) encoding:NSASCIIStringEncoding];
		NSLog(@"Old systemId: %@", oldSysId);
		*error = [self getSysId:user andKonto:konto];
		if (*error) {
			NSLog(@"hbcitool could not successfully send getSysId to bank.");
			return nil;
		}
		NSString * newSysId = [NSString stringWithCString:AH_User_GetSystemId(user) encoding:NSASCIIStringEncoding];
		NSLog(@"New systemId: %@", newSysId);
		// settings.conf speichern
#if defined(AQBANKING5)
		AB_Banking_SaveConfig(ab_);
#elif defined(AQBANKING4)
		AB_Banking_SaveConfig(ab_, 0);
#else
		AB_Banking_Save(ab_);
#endif
		
		[self log:[NSString localizedStringWithFormat:NSLocalizedString(@"Error excuting the jobs (%d)", nil), rv]];
		AB_Job_List2_FreeAll(jobList);
		*error = [self error:NSLocalizedString(@"hbcitool 'getTransactions' failed.", nil)];
		return nil;
	}
	
	// Transaktionen sammeln
	BOOL kontoauszugOk = NO;
	NSMutableArray * buchungen = nil;
	if (transactionsJob) {
		AB_JOB_STATUS js = AB_Job_GetStatus(transactionsJob);
		kontoauszugOk = YES;
		if (js != AB_Job_StatusFinished) {
			[self log:[NSString localizedStringWithFormat:@"Transaction job was not finished (%d)", js]];
			kontoauszugOk = NO;
		} else {
			buchungen = [NSMutableArray array];
			AB_IMEXPORTER_ACCOUNTINFO * accountInfo;
			accountInfo = AB_ImExporterContext_GetFirstAccountInfo(ctx);
			const AB_TRANSACTION * t;
			t = AB_ImExporterAccountInfo_GetFirstTransaction(accountInfo);
			while (t) {
				const AB_VALUE * v;
				v = AB_Transaction_GetValue(t);
				if (v) {
					const GWEN_STRINGLIST * sl;
					
					// Zweck (Zeilen durch "-" getrennt)
					sl = AB_Transaction_GetPurpose(t);
					NSString * purpose = [self foldStringList:sl withSep:@" - "];
					if (purpose == nil)
						purpose = @"";
					
					// Datum
					const GWEN_TIME * date = AB_Transaction_GetDate(t);
					if (date == 0)
						date = AB_Transaction_GetValutaDate(t);
					int unixSec;
					if (date)
						unixSec = GWEN_Time_Seconds(date);
					else {
						unixSec = 0;
						[self log:NSLocalizedString(@"Transaction without a date received. Strange.", nil)];
					}
					
					// Datum der Wertstellung
					const GWEN_TIME * dateValuta = AB_Transaction_GetValutaDate(t);
					int unixSecValuta;
					if (dateValuta)
						unixSecValuta = GWEN_Time_Seconds(dateValuta);
					else {
						unixSecValuta = 0;
						[self log:NSLocalizedString(@"Transaction without a date received. Strange.", nil)];
					}
					
					// Wert
					double value = AB_Value_GetValueAsDouble(v);
					NSString * svalue = [NSString stringWithFormat:@"%.2lf", value];
					const char * ccurrency = AB_Value_GetCurrency(v);
					NSString * currency = @"EUR";
					if (ccurrency)
						currency = [NSString stringWithUTF8String:ccurrency];
					
					// Remote-Stuff
					//const char * bankname = AB_Transaction_GetRemoteBankName(t);
					const char * bankcode = AB_Transaction_GetRemoteBankCode(t);
					//const char * remoteSuffix = AB_Transaction_GetRemoteSuffix(t);			
					//const char * branchid = AB_Transaction_GetRemoteBranchId(t);
					const char * remoteKonto = AB_Transaction_GetRemoteAccountNumber(t);
					//NSLog(@"%d, %d, %d, %d, %d", bankname, bankcode, branchid, remoteKonto, remoteSuffix);
					NSString * andereBank = @"";
					if (bankcode)
						andereBank = [NSString stringWithCString:bankcode encoding:NSUTF8StringEncoding];
					
					NSString * anderesKonto = @"";
					if (remoteKonto)
						anderesKonto = [NSString stringWithCString:remoteKonto encoding:NSUTF8StringEncoding];
					
					// Primanota
					NSString * primanota = @"";
					const char * pn = AB_Transaction_GetPrimanota(t);
					if (pn)
						primanota = [NSString stringWithCString:pn encoding:NSUTF8StringEncoding];
					
					const char * s = AB_Transaction_GetTransactionKey(t);
					if (s) NSLog(@"transactionKey => %@", [NSString stringWithCString:s encoding:NSUTF8StringEncoding]);
					s = AB_Transaction_GetCustomerReference(t);
					if (s) NSLog(@"customerRef => %@", [NSString stringWithCString:s encoding:NSUTF8StringEncoding]);
					s = AB_Transaction_GetBankReference(t);
					if (s) NSLog(@"bankRef => %@", [NSString stringWithCString:s encoding:NSUTF8StringEncoding]);
					s = AB_Transaction_GetTransactionText(t);
					if (s) NSLog(@"transText => %@", [NSString stringWithCString:s encoding:NSUTF8StringEncoding]);
					s = AB_Transaction_GetFiId(t);
					if (s) NSLog(@"fiId => %@", [NSString stringWithCString:s encoding:NSUTF8StringEncoding]);
					s = AB_Transaction_GetCustomerReference(t);
					if (s) NSLog(@"customerRef => %@", [NSString stringWithCString:s encoding:NSUTF8StringEncoding]);

					// Remote Name
					sl = AB_Transaction_GetRemoteName(t);
					NSString * remoteNames = [self foldStringList:sl withSep:@" - "];
					if (remoteNames == nil)
						remoteNames = @"";
					
					// Buchungsart
					s = AB_Transaction_GetTransactionText(t);
					NSString * buchungsArt = @"";
					if (s)
						buchungsArt = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
					
					// Buchung erzeugen
					NSDictionary * buchung = [NSDictionary dictionaryWithObjectsAndKeys:
								  [NSDecimalNumber decimalNumberWithString:svalue], @"wert",
								  currency, @"waehrung",
								  purpose, @"zweck",
								  buchungsArt, @"art",
								  andereBank, @"anderebank",
								  anderesKonto, @"andereskonto",
								  primanota, @"primanota",
								  remoteNames, @"anderername",
								  [NSDate dateWithTimeIntervalSince1970:unixSec], @"datum",
								  [NSDate date], @"datumGeladen",
								  [NSDate dateWithTimeIntervalSince1970:unixSecValuta], @"datumWertstellung",
								  nil];
					[buchungen addObject:buchung];
					//[self log:[NSString stringWithFormat:@"%@ (%.2lf %@)", purpose, value, currency]];
				}
				t = AB_ImExporterAccountInfo_GetNextTransaction(accountInfo);
			}
			[self log:[NSString localizedStringWithFormat:NSLocalizedString(@"Got %d transactions", nil), [buchungen count]]];
		}
	}
	
	// Balance auslesen
	*balance = NAN;
	BOOL kontostandOk = NO;
	if (balanceJob) {
		kontostandOk = YES;
		AB_JOB_STATUS js = AB_Job_GetStatus(balanceJob);
		if (js != AB_Job_StatusFinished) {
			kontostandOk = NO;
			[self log:[NSString localizedStringWithFormat:@"Balance job was not finished (%d)", js]];
		} else {
			AB_IMEXPORTER_ACCOUNTINFO * accountInfo;
			accountInfo = AB_ImExporterContext_GetFirstAccountInfo(ctx);
			const AB_ACCOUNT_STATUS * status;
			status = AB_ImExporterAccountInfo_GetFirstAccountStatus(accountInfo);
			while (status) {
				const AB_BALANCE * b = AB_AccountStatus_GetBookedBalance(status);
				if (!b)
					b = AB_AccountStatus_GetNotedBalance(status);
				if (!b) {
					fprintf(stderr, "No balance available\n");
					kontostandOk = NO;
				} else {
					const AB_VALUE * v = AB_Balance_GetValue(b);
					if (!v) {
						NSLog(@"Error getting balance value");
						kontostandOk = NO;
					} else {
						const char * currency = AB_Value_GetCurrency(v);
						if (currency)
							*balanceCurrency = [NSString stringWithCString:currency encoding:NSUTF8StringEncoding];
						*balance = AB_Value_GetValueAsDouble(v);
						kontostandOk = YES;
						//[self log:NSLocalizedString(@"Got new balance.", nil)];
					}
				}
				
				status = AB_ImExporterAccountInfo_GetNextAccountStatus(accountInfo);
			}
		}
	}
	if (kontostandOk) {
		[self log:NSLocalizedString(@"Got new balance.", nil)];
	}
	
	[self log:NSLocalizedString(@"Session finished", nil)];
	AB_Job_List2_FreeAll(jobList);
	
	// Fehler melden, weil kein Job funktioniert hat?
	if (!kontostandOk && !kontoauszugOk) {
		*error = [self error:
			  [NSString stringWithFormat:NSLocalizedString(@"Cannot get transactions for account number %@.", nil),
			   kontonummer]];
		return nil;
	}
	
	*error = nil;
	return buchungen;
}


- (BOOL)updateBankName:(Konto *)konto
{
	[konto setBankname:nil];
	NSString * blz = [konto bankleitzahl];
	
	// Banking neu oeffnen
	ok_ = [self openBankingFuerKonto:konto];
	if (!ok_) {
		[self log:NSLocalizedString(@"AqBanking init error.", nil)];
		return NO;
	}
	
	// Bank in der Datenbank finden
	AB_BANKINFO_LIST2 * bl = AB_BankInfo_List2_new();
	AB_BANKINFO * info = AB_BankInfo_new();
	AB_BankInfo_SetBankId(info, [blz UTF8String]);
	const char * land = [[konto land] cStringUsingEncoding:NSUTF8StringEncoding];
	int rv = AB_Banking_GetBankInfoByTemplate(ab_, land, info, bl);
	AB_BankInfo_free(info);
	if (rv != 0) {
		[self log:NSLocalizedString(@"Did not find bank.", nil)];
		return NO;
	}
	
	// Bank wurde gefunden. Wir nehmen nur die erste, falls mehrere gefunden wurden.
	AB_BANKINFO_LIST2_ITERATOR * it = AB_BankInfo_List2_First(bl);
	info = AB_BankInfo_List2Iterator_Data(it);
	if (!info) {
		[self log:NSLocalizedString(@"Did not find bank.", nil)];
		return NO;
	}
	
	// Bankname bekommen
	NSString * name = NSLocalizedString(@"Unknown bank", nil);
	const char * s;
	if (s = AB_BankInfo_GetBankName(info))
	    name = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
        [konto setBankname:name];
	
	// Ort der Bank bekommen
	NSString * loc = NSLocalizedString(@"Unknown bank location", nil);
	if (s = AB_BankInfo_GetLocation(info))
		loc = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
	else if (s = AB_BankInfo_GetCity(info))
		loc = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
	
	// HBCI-Server bekommen
	AB_BANKINFO_SERVICE_LIST * services = AB_BankInfo_GetServices(info);
	if (services) {
		AB_BANKINFO_SERVICE * service;
		service = AB_BankInfoService_List_First(services);
		while (service) {
			const char * address;
			if (strcasecmp(AB_BankInfoService_GetType(service),"hbci")==0
			    && strcasecmp(AB_BankInfoService_GetMode(service),"pintan")==0
			    && (address = AB_BankInfoService_GetAddress(service))) {
				NSString * server = [NSString stringWithCString:address
								       encoding:NSUTF8StringEncoding];
				NSLog(@"We found HBCI pintan service: %@", server);
				[konto setServer:server];
			}
			service = AB_BankInfoService_List_Next(service);
		}
	}
	
	// Wieder alles freigeben
	AB_BankInfo_List2_freeAll(bl);
	return YES;
}


- (SecKeychainRef)keychain
{
	NSLog(@"keychain => %d", keychain_);
	return keychain_;
}


@end
