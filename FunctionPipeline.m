// This research project is an attempt at the creating a "function pipeline"
// for animation. 
//
// There is a set of objects that "yield" selectors; these
// selectors are put onto a global buffer.
//
// A concurrent process checks the buffer on a periodical
// basis. If there are any selector pointers on the pipeline, it will perform
// the selectors.
//
// This is a model of an animation pipeline idea I have. We will have 
// a set of "yield"-like functions that create selectors that alter properties 
// of game objects. These functions are called each tick.
//
// Each function is put on to a stack and then all are executed concurrently before
// the scene is rendered. This is an alternative to the standard approach - 
// objects that perform their operations in a decremental stepwise manner.


#import <Foundation/Foundation.h>

@interface ContainerObject : NSObject 
{
	int num;
}
@property (readwrite) int num;
@end



@implementation ContainerObject
@synthesize num;
- init
{
	if ((self = [super init]))
	{
		num = 10;
	}
	return self;
}
@end




@interface Yielder: NSObject 
{
	ContainerObject *container;
}
@property (retain) ContainerObject *container;

//+ (int) foo:(int(*) (int))bar;
+ (Yielder *)GetInstance;
+ (SEL) StaticFunc;
+ (SEL) InstanceFunc;
@end


static Yielder *instance;
static int myNum = 100;

@implementation Yielder

@synthesize container;
- init
{
	if ((self = [super init]))
	{
		container = [[ContainerObject alloc] init];
	}
	return self;
}


- (void)MyInstanceFunc
{
	self.container.num += 1;
	printf("Container number: %i\n", self.container.num);
}


+ (Yielder *)GetInstance
{
	if (instance == nil)
	{
		instance = [[Yielder alloc] init];
	}
	return instance;
}


+ (void) MyFunc
{
	myNum += 1;
	printf("Instance Number: %i\n", myNum);
}


+ (SEL) StaticFunc
{
	return @selector(MyFunc);
}


+ (SEL) InstanceFunc
{
	return @selector(MyInstanceFunc);
}
@end



@interface PipelineController : NSObject
+ (void)StartPipeline;
+ (void)CreateFunction:(id)receiver withFunction:(SEL)selector;
+ (void)EndPipeline;
@end


@interface PipelineController (Private)
+ (void)Step;
+ (void)PipelineLoop;
@end

@implementation PipelineController

#define kPipelineSize 512

struct ReceiverSelectorPair
{
	id receiver;
	SEL selector;
};


static struct ReceiverSelectorPair pipeline[kPipelineSize];
static BOOL isRunning;
static NSObject * lock;
static NSTimeInterval updateInterval;
static int pipelineCount;

+ (void)StartPipeline
{	
	memset(pipeline, 0, sizeof(pipeline));
	
	isRunning = YES;
	updateInterval = 1.0 / 30;
	lock = [[NSObject alloc] init];
	
	[NSThread detachNewThreadSelector:@selector(PipelineLoop) toTarget:self withObject:nil];
}


// Loop used in the thread initialised by StartPipeline above.
//
// There is a faster timer available than the one used here.
+ (void)PipelineLoop
{
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSDate* date = [NSDate date];
	
	while(isRunning)
	{
		// timeIntervalSinceNow returns negative if receiver less than current date
		if (-[date timeIntervalSinceNow] >= updateInterval)
		{
			[self Step];
			date = [NSDate date];
		} 
		else
		{
			// Sleep for half the interval.
			NSTimeInterval t = (updateInterval / 2);
			[NSThread sleepForTimeInterval:t];
		}
	}
	
	[lock release];
	[pool drain];
}



// Perform all of the selectors on the pipeline.
+ (void)Step
{
	@synchronized(lock)
	{
		if (pipelineCount > 0)
		{
			for(int i = 0; i < pipelineCount; i++)
			{
				id receiver = pipeline[i].receiver;
				SEL selector = pipeline[i].selector;
				[receiver performSelector:selector onThread:[NSThread currentThread] withObject:nil waitUntilDone:YES];
			}
			
			pipelineCount = 0;
		}
	}
}



+ (void)CreateFunction:(id)receiver withFunction:(SEL)selector
{
	@synchronized(lock)
	{
		pipeline[pipelineCount].receiver = receiver;
		pipeline[pipelineCount].selector = selector;
		pipelineCount += 1;
	}
}


+ (void)EndPipeline
{
	isRunning = NO;
}
@end



@interface InputHelper : NSObject 
{
	BOOL isRunning;
}

@property (readwrite) BOOL isRunning;

- (void)InputLoop;

@end



@implementation InputHelper
@synthesize isRunning;
- init
{
	if ((self = [super init]))
	{
		self.isRunning = YES;
	}
	return self;
}


- (void)InputLoop
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	printf("Running input loop (type 's' for static function, 'i' for instance function, 'q' to quit\n");
	char ch; 
	
	while ((ch = getchar()) != 'q')
	{
		if (ch == 's')
		{
			[PipelineController CreateFunction:[Yielder class] withFunction:[Yielder StaticFunc]];
		} 
		else if (ch == 'i')
		{
			[PipelineController CreateFunction:(id)[Yielder GetInstance] withFunction:[Yielder InstanceFunc]];
		}
	}
	self.isRunning = NO;
	[pool drain];
}

@end


int main (int argc, const char * argv[]) 
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[PipelineController StartPipeline];	
	
	InputHelper* inp = [[InputHelper alloc] init];
	
	[NSThread detachNewThreadSelector:@selector(InputLoop) toTarget:inp withObject:nil];

	while (inp.isRunning) 
	{
		[NSThread sleepForTimeInterval:1.0];
	}
	
	[pool drain];
    return 0;
}
