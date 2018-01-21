//
//  VVViewContainer.m
//  VirtualView
//
//  Copyright (c) 2017-2018 Alibaba. All rights reserved.
//

#import "VVViewContainer.h"
#import "VVLayout.h"
#import "VVTemplateManager.h"

@interface VVViewContainer()<VVWidgetAction>{
    UILongPressGestureRecognizer* _pressRecognizer;
}
@property(nonatomic, strong)NSMutableArray *dataTagObjs;
@property(strong, nonatomic)NSMutableDictionary* dataCacheDic;
@property(weak, nonatomic)NSObject*            updateDataObj;
@end

@implementation VVViewContainer

+ (VVViewContainer *)viewContainerWithTemplateType:(NSString *)type
{
    VVBaseNode *vv = [[VVTemplateManager sharedManager] createNodeTreeForType:type];
    VVViewContainer *vvc = [[VVViewContainer alloc] initWithVirtualView:vv];
    [vvc attachViews];
    return vvc;
}

- (void)updateDisplayRect:(CGRect)rect{

}

- (void)handleLongPressed:(UILongPressGestureRecognizer *)gestureRecognizer{
    CGPoint pt =[gestureRecognizer locationInView:self];
    id<VVWidgetObject> vvobj=[self.virtualView hitTest:pt];
    if (vvobj!=nil && [(VVBaseNode*)vvobj isLongClickable]) {
        [self.delegate subViewLongPressed:vvobj.action andValue:vvobj.actionValue gesture:gestureRecognizer];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch *touch =  [touches anyObject];
    CGPoint pt = [touch locationInView:self];
    id<VVWidgetObject> vvobj=[self.virtualView hitTest:pt];
    if (vvobj!=nil && [(VVBaseNode*)vvobj isClickable]) {
        if([self.delegate respondsToSelector:@selector(subView:clicked:andValue:)])
        {
            [self.delegate subView:vvobj clicked:vvobj.action andValue:vvobj.actionValue];
        }
        else if([self.delegate respondsToSelector:@selector(subViewClicked:andValue:)])
        {
            [self.delegate subViewClicked:vvobj.action andValue:vvobj.actionValue];
        }
    }else{
        [super touchesEnded:touches withEvent:event];
    }
}

- (id)initWithVirtualView:(VVBaseNode*)virtualView{
    self = [super init];
    if (self) {
        self.virtualView = virtualView;
        self.virtualView.updateDelegate = self;
        self.backgroundColor = [UIColor clearColor];
        self.dataCacheDic = [[NSMutableDictionary alloc] init];
        _dataTagObjs = [NSMutableArray array];
        [VVViewContainer getDataTagObjsHelper:virtualView collection:_dataTagObjs];
        if ([self.virtualView isLongClickable]) {
            _pressRecognizer =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressed:)];
            [self addGestureRecognizer:_pressRecognizer];
        }
    }
    return self;
}

- (void) attachViews {
    [self attachViews:self.virtualView];
}

- (void) attachViews:(VVBaseNode*)virtualView {
    
    if ([virtualView isKindOfClass:VVLayout.class]) {
        for (VVLayout* item in virtualView.subViews) {
            [self attachViews:item];
        }
    } else if(virtualView.cocoaView && virtualView.visible!=VVVisibilityGone) {
        [self addSubview:virtualView.cocoaView];
    }
}

- (int)getValue4Array:(NSArray*)arr{
    int value=0;
    for (NSString* item in arr) {
        if ([item compare:@"left" options:NSCaseInsensitiveSearch]) {
            value=value|VVGravityLeft;
        }else if ([item compare:@"right" options:NSCaseInsensitiveSearch]){
            value=value|VVGravityRight;
        }else if ([item compare:@"h_center" options:NSCaseInsensitiveSearch]){
            value=value|VVGravityHCenter;
        }else if ([item compare:@"top" options:NSCaseInsensitiveSearch]){
            value=value|VVGravityTop;
        }else if ([item compare:@"bottom" options:NSCaseInsensitiveSearch]){
            value=value|VVGravityBottom;
        }else if ([item compare:@"v_center" options:NSCaseInsensitiveSearch]){
            value=value|VVGravityVCenter;
        }else if ([item compare:@"center" options:NSCaseInsensitiveSearch]){
            value=value|VVGravityHCenter|VVGravityVCenter;
        }
    }
    return value;
}
- (NSString*)valueForVariable:(id)obj fromJsonData:(NSDictionary*)jsonData{

    NSString* valueObj = nil;

    if ([obj isKindOfClass:NSArray.class]) {
        NSDictionary* tmpDictionary = jsonData;
        NSArray* varList = (NSArray*)obj;
        for (NSDictionary* varItem in varList) {
            NSString* varName = [varItem objectForKey:@"varName"];
            int index = [[varItem objectForKey:@"varIndex"] intValue];

            if (index>=0) {
                NSArray* items = [tmpDictionary objectForKey:varName];
                if (items.count>index) {
                    valueObj = [items objectAtIndex:index];
                }else{
                    valueObj = @"";
                }
            }else{
                valueObj = [tmpDictionary objectForKey:varName];
            }

            if ([valueObj isKindOfClass:NSDictionary.class]) {
                tmpDictionary = (NSDictionary*)valueObj;
            }

        }
    }else{
        NSString* varString = (NSString*)obj;
        NSRange startPos = [varString rangeOfString:@"${"];
        if (startPos.location==NSNotFound) {
            return varString;
        }

        NSRange endPos   = [varString rangeOfString:@"}" options:NSCaseInsensitiveSearch range:NSMakeRange(startPos.location, varString.length-startPos.location)];

        if (endPos.location==NSNotFound) {
            return varString;
        }

        if (startPos.location!=NSNotFound && endPos.location!=NSNotFound && endPos.location>startPos.location) {
            NSString* key = [varString substringWithRange:NSMakeRange(startPos.location+2, endPos.location-startPos.length)];
            valueObj = [jsonData objectForKey:key];
        }
    }

    return valueObj;
}
- (void)update:(NSObject*)obj{
    if (obj==nil || obj==self.updateDataObj) {
        return;
    }else{
        self.updateDataObj = obj;
    }
    NSDictionary* jsonData = (NSDictionary*)obj;

    NSMutableArray* widgetValues = [[NSMutableArray alloc] init];
    for (VVBaseNode* item in self.dataTagObjs) {
        [item reset];

        for (NSNumber* key in [item.mutablePropertyDic allKeys]) {

            NSMutableDictionary* dataCache = [[NSMutableDictionary alloc] init];
            [widgetValues addObject:dataCache];
            [dataCache setObject:item forKey:@"object"];

            NSDictionary* propertyInfo = [item.mutablePropertyDic objectForKey:key];
            [dataCache setObject:key forKey:@"key"];

            NSNumber* valueType = [propertyInfo objectForKey:@"valueType"];
            [dataCache setObject:valueType forKey:@"type"];

            NSArray* varObj = [propertyInfo objectForKey:@"varValues"];
            NSObject* valueObj = nil;
            NSDictionary* tmpDictionary = jsonData;
            NSString* varName = nil;
            if([varObj isKindOfClass:NSArray.class]){
                for (NSDictionary* varItem in varObj) {
                    NSString* var = [varItem objectForKey:@"varName"];
                    int index = [[varItem objectForKey:@"varIndex"] intValue];
                    if (index>=0) {
                        NSArray* items = [tmpDictionary objectForKey:var];
                        if (items.count>index) {
                            valueObj = [items objectAtIndex:index];
                        }else{
                            valueObj = nil;
                            break;
                        }
                    }else{
                        valueObj = [tmpDictionary objectForKey:var];
                    }

                    if ([valueObj isKindOfClass:NSDictionary.class]) {
                        tmpDictionary = (NSDictionary*)valueObj;
                    }

                    varName = var;
                }
            }else if ([varObj isKindOfClass:NSString.class]){
                valueObj = [tmpDictionary objectForKey:varObj];
                varName = (NSString*)varObj;
            }

            int keyValue = [key intValue];
            int intValue = 0;
            NSObject* objValue = nil;
            switch ([valueType intValue]) {
                case TYPE_INT:
                {
                    int value=0;
                    if ([propertyInfo allValues].count>2) {
                        NSObject* objValue;
                        if (((NSString*)valueObj).length>0 && [(NSString*)valueObj isEqualToString:@"false"]==NO) {
                            objValue = [propertyInfo objectForKey:@"v1"];
                        }else{
                            objValue = [propertyInfo objectForKey:@"v2"];
                        }
                        value = [[self valueForVariable:objValue fromJsonData:jsonData] intValue];
                    }else{
                        value = [(NSNumber*)valueObj intValue];
                    }
                    [item setIntValue:value forKey:keyValue];
                    [dataCache setObject:[NSNumber numberWithInt:value] forKey:@"value"];

                }
                    break;
                case TYPE_FLOAT:
                {
                    CGFloat value=0;
                    if ([propertyInfo allValues].count>2) {
                        NSObject* objValue;
                        if (((NSString*)valueObj).length>0 && [(NSString*)valueObj isEqualToString:@"false"]==NO) {
                            objValue = [propertyInfo objectForKey:@"v1"];
                        }else{
                            objValue = [propertyInfo objectForKey:@"v2"];
                        }
                        value = [[self valueForVariable:objValue fromJsonData:jsonData] floatValue];
                    }else{
                        value = [(NSNumber*)valueObj floatValue];
                    }
                    [item setFloatValue:value forKey:keyValue];
                    [dataCache setObject:[NSNumber numberWithFloat:value] forKey:@"value"];

                }
                    break;
                case TYPE_STRING:
                {
                    NSString* value=@"";
                    if ([propertyInfo allValues].count>2) {
                        if (((NSString*)valueObj).length>0 && [(NSString*)valueObj isEqualToString:@"false"]==NO) {
                            value = [propertyInfo objectForKey:@"v1"];
                        }else{
                            value = [propertyInfo objectForKey:@"v2"];
                        }
                        value = [self valueForVariable:value fromJsonData:jsonData];
                    }else{
                        value = (NSString*)valueObj;
                    }
                    if (value) {
                        [item setStringDataValue:value forKey:keyValue];
                        [dataCache setObject:value forKey:@"value"];
                    }
                }
                    break;
                case TYPE_COLOR:
                {
                    NSString* value=@"";
                    if ([propertyInfo allValues].count>2) {
                        if (((NSString*)valueObj).length>0 && [(NSString*)valueObj isEqualToString:@"false"]==NO) {
                            value = [propertyInfo objectForKey:@"v1"];
                        }else{
                            value = [propertyInfo objectForKey:@"v2"];
                        }
                        value = [self valueForVariable:value fromJsonData:jsonData];
                    }else{
                        value = (NSString*)valueObj;
                    }
                    if (value) {
                        [item setStringDataValue:value forKey:keyValue];
                        [dataCache setObject:value forKey:@"value"];
                    }
                }
                    break;
                case TYPE_BOOLEAN:
                {
                    NSString* value=@"";
                    if ([propertyInfo allValues].count>2) {
                        if (((NSString*)valueObj).length>0 && [(NSString*)valueObj isEqualToString:@"false"]==NO) {
                            value = [propertyInfo objectForKey:@"v1"];
                        }else{
                            value = [propertyInfo objectForKey:@"v2"];
                        }
                    }else{
                        value = (NSString*)valueObj;
                    }

                    value = [self valueForVariable:value fromJsonData:jsonData];
                    if ([value isEqualToString:@"true"]) {
                        intValue = 1;
                    }else{
                        intValue = 0;
                    }
                    [item setIntValue:intValue forKey:keyValue];
                    [dataCache setObject:[NSNumber numberWithInt:intValue] forKey:@"value"];
                }
                    break;
                case TYPE_VISIBILITY:
                {
                    NSString* value=@"";
                    if ([propertyInfo allValues].count>2) {
                        if ((valueObj!=nil && ![valueObj isKindOfClass:NSString.class]) || (((NSString*)valueObj).length>0 && [(NSString*)valueObj isEqualToString:@"false"]==NO)) {
                            value = [propertyInfo objectForKey:@"v1"];
                        }else{
                            value = [propertyInfo objectForKey:@"v2"];
                        }
                        value = [self valueForVariable:value fromJsonData:jsonData];
                    }else{
                        value = (NSString*)valueObj;
                    }

                    if ([value isEqualToString:@"invisible"]) {
                        intValue = VVVisibilityInvisible;
                    }else if([value isEqualToString:@"visible"]) {
                        intValue = VVVisibilityVisible;
                    }else{
                        intValue = VVVisibilityGone;
                    }
                    [item setIntValue:intValue forKey:[key intValue]];
                    [dataCache setObject:[NSNumber numberWithInt:intValue] forKey:@"value"];
                }
                    break;
                case TYPE_GRAVITY:
                {
                    NSString* value=@"";
                    if ([propertyInfo allValues].count>2) {
                        if (((NSString*)valueObj).length>0 && [(NSString*)valueObj isEqualToString:@"false"]==NO) {
                            value = [propertyInfo objectForKey:@"v1"];
                        }else{
                            value = [propertyInfo objectForKey:@"v2"];
                        }
                        value = [self valueForVariable:value fromJsonData:jsonData];
                    }else{
                        value = (NSString*)valueObj;
                    }

                    intValue = [self getValue4Array:[value componentsSeparatedByString:@"|"]];
                    [item setIntValue:intValue forKey:keyValue];
                    [dataCache setObject:[NSNumber numberWithInt:intValue] forKey:@"value"];
                }
                    break;
                case TYPE_OBJECT:
                    objValue = [jsonData objectForKey:varName];
                    if (objValue) {
                        [item setDataObj:objValue forKey:keyValue];
                        [dataCache setObject:objValue forKey:@"value"];
                    }
                    break;
                default:
                    break;
            }
        }
        item.actionValue = [jsonData objectForKey:item.action];
        
        [item didFinishBinding];
    }
    [self.dataCacheDic setObject:widgetValues forKey:jsonData];

    [self.virtualView calculateLayoutSize:self.frame.size];
    
    [self.virtualView layoutSubviews];
    [self setNeedsDisplay];

}

- (VVBaseNode*)findObjectByID:(int)tagid{
    VVBaseNode* obj=[self.virtualView findViewByID:tagid];
    return obj;
}

+ (void)getDataTagObjsHelper:(VVBaseNode *)node collection:(NSMutableArray *)dataTagObjs
{
    if (node.mutablePropertyDic.count > 0) {
        [dataTagObjs addObject:node];
    }
    for (VVBaseNode *subNode in node.subViews) {
        [self getDataTagObjsHelper:subNode collection:dataTagObjs];
    }
}

@end
