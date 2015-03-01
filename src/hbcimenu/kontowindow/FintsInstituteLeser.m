//
//  FintsInstituteLeser.m
//  hbci
//
//  Created by Stefan Schimanski on 16.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "FintsInstituteLeser.h"

#import "fints_institute.h"
#import "debug.h"
#import "NSString+CSVUtils.h"


@implementation FintsInstituteLeser

- (id) init
{
	self = [super init];
	data_ = nil;
	blzToData_ = nil;
	return self;
}



- (void)awakeFromNib
{
}


- (void) dealloc
{
	[data_ release];
	[blzToData_ release];
	[super dealloc];
}


- (void)add:(NSString *)blz name:(NSString *)name server:(NSString *)server hbciVer:(NSString *)ver
{
	[blzToData_ setObject:[NSMutableArray arrayWithObjects:
			       @"",blz,name,@"",@"",@"",@"",@"",ver,@"",@"",@"",@"",@"",@"",
			       @"",@"",@"",@"",@"",
			       server,@"",@"",nil]
		       forKey:blz];
}


- (void)laden
{
	// Daten laden
	data_ = [[NSString stringWithCString:bin_data encoding:NSWindowsCP1252StringEncoding] arrayByImportingCSV];
	blzToData_ = [NSMutableDictionary new];
	
	// fehlende Banken
	
	// Exoten
	[self add:@"73331700" name:@"Saliterbank." server:@"https://www.bv-activebanking.de/hbciTunnel/hbciTransfer.jsp" hbciVer:@"2.2"];
	[self add:@"20090500" name:@"Netbank AG." server:@"https://www.bankingonline.de/hbci/pintan/PinTanServlet" hbciVer:@"2.2"];
	
	// Sparda Bank
	[self add:@"40060560" name:@"Sparda-Bank." server:@"https://www.bankingonline.de/hbci/pintan/PinTanServlet" hbciVer:@"2.2"];
	[self add:@"60090800" name:@"Sparda-Bank." server:@"https://www.bankingonline.de/hbci/pintan/PinTanServlet" hbciVer:@"2.2"];
		
	// PSD-Bank
	[self add:@"20090900" name:@"PSD Bank." server:@"https://hbci11.fiducia.de/cgi-bin/hbciservlet" hbciVer:@"3.0"];
	[self add:@"10090900" name:@"PSD Bank." server:@"https://hbci11.fiducia.de/cgi-bin/hbciservlet" hbciVer:@"3.0"];
	[self add:@"40090900" name:@"PSD Bank." server:@"https://hbci11.fiducia.de/cgi-bin/hbciservlet" hbciVer:@"3.0"];
	[self add:@"66090900" name:@"PSD Bank." server:@"https://hbci11.fiducia.de/cgi-bin/hbciservlet" hbciVer:@"3.0"];
	
	// comdirect
	[self add:@"20041111" name:@"Comdirect." server:@"https://hbci.comdirect.de/pintan/HbciPinTanHttpGate" hbciVer:@"2.2"];
	[self add:@"20041133" name:@"Comdirect." server:@"https://hbci.comdirect.de/pintan/HbciPinTanHttpGate" hbciVer:@"2.2"];
	[self add:@"20041144" name:@"Comdirect." server:@"https://hbci.comdirect.de/pintan/HbciPinTanHttpGate" hbciVer:@"2.2"];
	[self add:@"20041155" name:@"Comdirect." server:@"https://hbci.comdirect.de/pintan/HbciPinTanHttpGate" hbciVer:@"2.2"];
	
	// fints-Daten
	int i;
	for (i = 0; i < [data_ count]; i++) {
		NSArray * zeile = [data_ objectAtIndex:i];
		//NSLog(@"content of line %d: %@", i, zeile);
		if ([[zeile objectAtIndex:FintsInstitutePinTanUrl] isEqualToString:@""]) {
			NSLog(@"Zeile verfügt über keine Pin/Tan-URL: Zeile wird ignoriert.");
		} else {
			[blzToData_ setObject:zeile forKey:[zeile objectAtIndex:FintsInstituteBankleitzahl]];
		}

		//[blzToData_ setObject:zeile forKey:[zeile objectAtIndex:FintsInstituteBankleitzahl]];
	}
	
	// korrigierte Daten
	
	// Da wir HBCI 4.0 noch nicht unterstützen!
	/*[self add:@"30020500" name:@"BHF-Bank AG." server:@"https://www.bv-activebanking.de/hbciTunnel/hbciTransfer.jsp" hbciVer:@"3.0"];
	[self add:@"50020200" name:@"BHF-Bank AG." server:@"https://www.bv-activebanking.de/hbciTunnel/hbciTransfer.jsp" hbciVer:@"3.0"];
	[self add:@"51020000" name:@"BHF-Bank AG." server:@"https://www.bv-activebanking.de/hbciTunnel/hbciTransfer.jsp" hbciVer:@"3.0"];
	[self add:@"55020000" name:@"BHF-Bank AG." server:@"https://www.bv-activebanking.de/hbciTunnel/hbciTransfer.jsp" hbciVer:@"3.0"];
	[self add:@"60120200" name:@"BHF-Bank AG." server:@"https://www.bv-activebanking.de/hbciTunnel/hbciTransfer.jsp" hbciVer:@"3.0"];
	[self add:@"70220200" name:@"BHF-Bank AG." server:@"https://www.bv-activebanking.de/hbciTunnel/hbciTransfer.jsp" hbciVer:@"3.0"];
	[self add:@"86020200" name:@"BHF-Bank AG." server:@"https://www.bv-activebanking.de/hbciTunnel/hbciTransfer.jsp" hbciVer:@"3.0"];*/
	
	// Exoten
	[self add:@"50010517" name:@"Ing-Diba." server:@"https://fints.ing-diba.de/fints/" hbciVer:@"2.2"];
	[self add:@"79030001" name:@"Fürstlich Castell'sche Bank." server:@"https://hbci-pintan.gad.de/cgi-bin/hbciservlet" hbciVer:@"3.0"];
	
	// Sparkassen
	//[self add:@"50050201" name:@"Frankfurter Sparkasse 1822." server:@"https://hbci-pintan-he.s-hbci.de/PinTanServlet" hbciVer:@"3.0"];
	[self add:@"29050101" name:@"Sparkasse Bremen." server:@"https://hbci-pintan-hb.s-hbci.de/PinTanServlet" hbciVer:@"2.2"];
	
	// Deutsche Bank
	NSArray * dbank = [NSArray arrayWithObjects:
			   @"10070000",
			   @"10070024",
			   @"10070100",
			   @"10070124",
			   @"10070848",
			   @"12070000"
			   @"12070024",
			   @"13070000",
			   @"13070024",
			   @"20010800",
			   @"20070000",
			   @"20070024",
			   @"20110401",
			   @"21070020",
			   @"21070024",
			   @"21270020",
			   @"21270024",
			   @"21570011",
			   @"21570024",
			   @"21770011",
			   @"21770024",
			   @"23070700",
			   @"23070710",
			   @"24070024",
			   @"24070075",
			   @"25070025",
			   @"25070066",
			   @"25070070",
			   @"25070077",
			   @"25070084",
			   @"25070086",
			   @"25470024",
			   @"25470073",
			   @"25470078",
			   @"25471024",
			   @"25471073",
			   @"25770024",
			   @"25770069",
			   @"25970024",
			   @"25970074",
			   @"25971024",
			   @"25971071",
			   @"26070024",
			   @"26070072",
			   @"26070072",
			   @"26271424",
			   @"26271471",
			   @"26570024",
			   @"26570090",
			   @"26770024",
			   @"26770095",
			   @"26870024",
			   @"26870032",
			   @"26971024",
			   @"26971038",
			   @"27070024",
			   @"27070030",
			   @"27070031",
			   @"27070034",
			   @"27070041",
			   @"27070042",
			   @"27070043",
			   @"27070079",
			   @"27072524",
			   @"27072537",
			   @"27072724",
			   @"27072736",
			   @"28070024",
			   @"28070057",
			   @"28270024",
			   @"28270056",
			   @"28470024",
			   @"28470091",
			   @"28570024",
			   @"28570024",
			   @"28570092",
			   @"29070024",
			   @"29070050",
			   @"29070051",
			   @"29070052",
			   @"29070058",
			   @"29070059",
			   @"29172624",
			   @"29172655",
			   @"30070010",
			   @"30070024",
			   @"31070001",
			   @"31070024",
			   @"31470004",
			   @"32070024",
			   @"32070080",
			   @"32470024",
			   @"32470077",
			   @"33070024",
			   @"33070090",
			   @"34070024",
			   @"34070093",
			   @"34270024",
			   @"34270094",
			   @"35070024",
			   @"35070030",
			   @"36070024",
			   @"36070050",
			   @"36270024",
			   @"36270048",
			   @"36570024",
			   @"36570049",
			   @"37070024",
			   @"37070060",
			   @"37570024",
			   @"38070024",
			   @"38070059",
			   @"38070724",
			   @"38077724",
			   @"38470024",
			   @"38470091",
			   @"39070020",
			   @"39070024",
			   @"39570061",
			   @"40070024",
			   @"40070080",
			   @"40370024",
			   @"40370079",
			   @"41070024",
			   @"41070049",
			   @"41670024",
			   @"41670027",
			   @"41670028",
			   @"41670029",
			   @"41670030",
			   @"42070024",
			   @"42070062",
			   @"42870024",
			   @"42870077",
			   @"43070024",
			   @"43070061",
			   @"44070024",
			   @"44070050",
			   @"44570004",
			   @"44570024",
			   @"45070002",
			   @"45070024",
			   @"46070024",
			   @"46070090",
			   @"46670007",
			   @"46670024",
			   @"47270024",
			   @"47270029",
			   @"47670023",
			   @"47670024",
			   @"48050000",
			   @"48070020",
			   @"48070024",
			   @"48070040",
			   @"48070042",
			   @"48070043",
			   @"48070044",
			   @"48070045",
			   @"48070046",
			   @"48070050",
			   @"48070051",
			   @"48070052",
			   @"49070024",
			   @"49070028",
			   @"50070010",
			   @"50070024",
			   @"50073019",
			   @"50073024",
			   @"50570018",
			   @"50570024",
			   @"50670009",
			   @"50670024",
			   @"50870005",
			   @"50870024",
			   @"51070021",
			   @"51070024",
			   @"51170010",
			   @"51170024",
			   @"51230100",
			   @"51370008",
			   @"51370024",
			   @"51570008",
			   @"51570024",
			   @"52070012",
			   @"52070024",
			   @"52071212",
			   @"52071224",
			   @"52270012",
			   @"52270024",
			   @"53070007",
			   @"53070024",
			   @"53270012",
			   @"53270024",
			   @"53370008",
			   @"53370024",
			   @"54070092",
			   @"54270024",
			   @"54270096",
			   @"54570024",
			   @"54570094",
			   @"54670024",
			   @"54670095",
			   @"55020600",
			   @"55070024",
			   @"55070040",
			   @"56070024",
			   @"56070040",
			   @"56270024",
			   @"56270044",
			   @"57070024",
			   @"57070045",
			   @"57470024",
			   @"57470047",
			   @"58570024",
			   @"58771224",
			   @"58771242",
			   @"59070000",
			   @"60070024",
			   @"60070070",
			   @"60270024",
			   @"60270073",
			   @"60470024",
			   @"60470082",
			   @"60670024",
			   @"60670070",
			   @"61070024",
			   @"61070078",
			   @"61170024",
			   @"61170076",
			   @"61370024",
			   @"61370086",
			   @"62070024",
			   @"62070081",
			   @"63070024",
			   @"63070088",
			   @"64070024",
			   @"64070085",
			   @"65070024",
			   @"65070084",
			   @"65370024",
			   @"65370075",
			   @"66070004",
			   @"66070024",
			   @"66270001",
			   @"66270024",
			   @"66470035",
			   @"66670006",
			   @"66670024",
			   @"67070010",
			   @"67070024",
			   @"67270003",
			   @"67270024",
			   @"68070030",
			   @"68270024",
			   @"68270033",
			   @"68370024",
			   @"68370034",
			   @"69070024",
			   @"69070032",
			   @"69270024",
			   @"69270038",
			   @"69470024",
			   @"69470039",
			   @"70070010",
			   @"70070024",
			   @"72070001",
			   @"72070024",
			   @"72170007",
			   @"72170024",
			   @"73370008",
			   @"73370024",
			   @"75070013",
			   @"75070024",
			   @"75020024",
			   @"76070012",
			   @"76070024",
			   @"79070016",
			   @"79070024",
			   @"79570051",
			   @"81070000",
			   @"81070024",
			   @"82070000",
			   @"82070024",
			   @"86070000",
			   @"86070024",
			   @"87070000",
			   @"87070024",nil];
	for (NSString * blz in dbank) {
		[self add:blz name:@"Deutsche Bank." server:@"https://fints.deutsche-bank.de" hbciVer:@"2.2"];
	}
	
	// Dresdner Bank
	NSArray * dresdnerbank = [NSArray arrayWithObjects:
			   @"10080000",
			   //@"12080000",
			   @"13080000",
			   @"14080000",
			   @"15080000",
			   @"16080000",
			   @"17080000",
			   @"18080000",
			   @"20080000",
			   @"21080050",
			   @"21280002",
			   @"21480003",
			   @"21580000",
			   @"22180000",
			   @"22181400",
			   @"22280000",
			   @"23080040",
			   @"24080000",
			   @"24180000",
			   @"24180001",
			   @"25080020",
			   @"25480021",
			   @"25780022",
			   //@"25980027",
			   //@"26080024",
			   //@"26280020",
			   //@"26281420",
			   //@"26580070",
			   //@"26880063",
			   //@"26981062",
			   //@"27080060",
			   //@"28280012",
			   //@"29080010",
			   //@"29280011",
			   //@"30080000",
			   //@"31080015",
			   //@"32080010",
			   //@"33080030",
			   //@"34080031",
			   //@"34280032",
			   //@"35080070",
			   //@"36080080",
			   //@"36280071",
			   //@"36580072",
			   //@"37080040",
			   //@"38080055",
			   //@"39080005",
			   //@"39580041",
			   //@"40080040",
			   //@"41280043",
			   //@"42080082",
			   //@"42680081",
			   //@"43080083",
			   //@"44080050",
			   //@"44580070",
			   nil];
	for (NSString * blz in dresdnerbank) {
		[self add:blz name:@"Dresdner Bank." server:@"https://hbci.dresdner-bank.de" hbciVer:@"3.0"];
	}
	
}


- (NSArray *)bankDaten:(NSString *)bankleitzahl
{
	if (data_ == nil)
		[self laden];
	
	return [blzToData_ objectForKey:bankleitzahl];
}

@end
