// Copyright 1997-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OmniInspector.h 93428 2007-10-25 16:36:11Z kc $

#import "OAApplication-OIExtensions.h"
#import "OAToolbarWindowController-OIExtensions.h"

#import "OIInspector.h"
#import "OIInspectableControllerProtocol.h"
#import "OIInspectionSet.h"
#import "OIInspectorController.h"
#import "OIInspectorRegistry.h"

// These are needed for OmniGraffle, but might not need to be public after the tabbed-inspector merge.  Reevaluate after that and make non-public if possible
#import "OIInspectorGroup.h"
#import "OITabbedInspector.h"
