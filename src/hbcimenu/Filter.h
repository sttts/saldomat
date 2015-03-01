//
//  Filter.h
//  hbci
//
//  Created by Stefan Schimanski on 23.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Aktion;


enum FilterAktiverView
{
	FilterKeinAktiverView = 0,
	FilterAktiverAktionenView,
	FilterAktiverKriterienView
};
typedef enum FilterAktiverView FilterAktiverView;


@interface Filter : NSObject {
	NSPredicate * predicate_;
	NSString * title_;
	NSMutableArray * aktionen_;
	FilterAktiverView aktiverView_;
}

@property (copy) NSPredicate * predicate;
@property (retain) NSString * title;
@property FilterAktiverView aktiverView;

- (NSArray *)aktionen;
- (int)countOfAktionen;
- (NSDictionary *)objectInAktionenAtIndex:(int)i;
- (void)insertObject:(Aktion *)aktion inAktionenAtIndex:(int)i;
- (void)removeObjectFromAktionenAtIndex:(int)i;

@end


@interface SharedFilters : NSObject
{
	NSMutableArray * filters_;
}

- (NSArray *)filters;
- (int)countOfFilters;
- (Filter *)objectInFiltersAtIndex:(int)i;
- (void)insertObject:(Filter *)filter inFiltersAtIndex:(int)i;
- (void)removeObjectFromFiltersAtIndex:(int)i;

@end
