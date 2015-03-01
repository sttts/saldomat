//--------------------------------------------------------------------

//
//  NSString-Levenshtein.m
//
//  Created by Rick Bourner on Sat Aug 09 2003.
//  Rick@Bourner.com
//------------------------------------------------------------------------

#import "NSString-Levenshtein.h"

@implementation NSString(Levenshtein)

// calculate the mean distance between all words in stringA and stringB
- (float) compareWithString: (NSString *) stringB
{
    float averageSmallestDistance = 0.0;
    float smallestDistance;
    float distance;

    NSMutableString * mStringA = [[NSMutableString alloc]  initWithString: self];
    NSMutableString * mStringB = [[NSMutableString alloc]  initWithString: stringB];

    // normalize
    [mStringA replaceOccurrencesOfString:@"\n"
        withString: @" "
        options: NSLiteralSearch
        range: NSMakeRange(0, [mStringA  length])];

    [mStringB replaceOccurrencesOfString:@"\n"
        withString: @" "
        options: NSLiteralSearch
        range: NSMakeRange(0, [mStringB  length])];

    NSArray * arrayA = [mStringA componentsSeparatedByString: @" "];
    NSArray * arrayB = [mStringB componentsSeparatedByString: @" "];

    NSEnumerator * emuA = [arrayA objectEnumerator];
    NSEnumerator * emuB;

    NSString * tokenA = NULL;
    NSString * tokenB = NULL;

    // O(n*m) but is there another way ?!?
    while ( tokenA = [emuA nextObject] )
    {

        emuB = [arrayB objectEnumerator];
        smallestDistance = 99999999.0;

        while ( tokenB = [emuB nextObject] )
            if ( (distance = [tokenA compareWithWord: tokenB] ) <  smallestDistance )
            smallestDistance = distance;

        averageSmallestDistance += smallestDistance;

    }

    [mStringA release];
    [mStringB release];

    return averageSmallestDistance / [arrayA count];
}

// calculate the distance between two string treating them eash as a
// single word
- (float) compareWithWord: (NSString *) stringB
{
    // normalize strings
    NSString * stringA = [NSString stringWithString: self];
    [stringA stringByTrimmingCharactersInSet:
    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [stringB stringByTrimmingCharactersInSet:
    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    stringA = [stringA lowercaseString];
    stringB = [stringB lowercaseString];

    // Step 1
    int k, i, j, cost, * d, distance;

    int n = [stringA length];
    int m = [stringB length];

    if( n++ != 0 && m++ != 0 )
    {

        d = malloc( sizeof(int) * m * n );

        // Step 2
        for( k = 0; k < n; k++)
            d[k] = k;

        for( k = 0; k < m; k++)
            d[ k * n ] = k;

        // Step 3 and 4
        for( i = 1; i < n; i++ )
            for( j = 1; j < m; j++ )
        {

            // Step 5
            if( [stringA characterAtIndex: i-1] ==
                [stringB characterAtIndex: j-1] )
                cost = 0;
            else
                cost = 1;

            // Step 6
            d[ j * n + i ] = [self smallestOf: d [ (j - 1) * n + i ] + 1
                andOf: d[ j * n + i - 1 ] +  1
                andOf: d[ (j - 1) * n + i -1 ] + cost ];
        }

        distance = d[ n * m - 1 ];

        free( d );

        return distance;
    }
    return 0.0;
}

// return the minimum of a, b and c
- (int) smallestOf: (int) a andOf: (int) b andOf: (int) c
{
    int min = a;
    if ( b < min )
        min = b;

    if( c < min )
        min = c;

    return min;
}

@end
