//
//  FintsInstituteLeser.h
//  hbci
//
//  Created by Stefan Schimanski on 16.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// 0-4:   Nr.;BLZ;Institut;Ort;RZ;
// 5-9:   Organisation, HBCI-Zugang DNS;HBCI- Zugang IP-Adresse;HBCI-Version;DDV;
// 10-14: RDH-1;RDH-2;RDH-3;RDH-4;RDH-5;
// 15-19: PIN/TAN-Zugang URL;Version;Datum letzte Änderung

enum FintsInstituteSpalten
{
	FintsInstituteNummer = 0,
	FintsInstituteBankleitzahl,
	FintsInstituteName,
	FintsInstituteOrt,
	FintsInstituteRz,
	
	FintsInstituteOrganisation,
	FintsInstituteHbciDNS,
	FintsInstituteHbciIP,
	FintsInstituteHbciVersion,
	FintsInstituteHbciDDV,
	
	FintsInstituteHbciRDH1,
	FintsInstituteHbciRDH2,
	FintsInstituteHbciRDH3,
	FintsInstituteHbciRDH4,
	FintsInstituteHbciRDH5,
	FintsInstituteHbciRDH6,
	FintsInstituteHbciRDH7,
	FintsInstituteHbciRDH8,
	FintsInstituteHbciRDH9,
	FintsInstituteHbciRDH10,
	
	FintsInstitutePinTanUrl,
	FintsInstituteVersion,
	FintsInstituteDatumLetzteAenderung,
	
	FintsInstituteMax
};

@interface FintsInstituteLeser : NSObject {
	NSMutableArray * data_;
	NSMutableDictionary * blzToData_;
}

- (NSArray *)bankDaten:(NSString *)bankleitzahl;

@end
