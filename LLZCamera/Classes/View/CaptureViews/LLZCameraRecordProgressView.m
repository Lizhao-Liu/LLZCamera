//
//  LLZCameraRecordProgressView.m
//  AAChartKit
//
//  Created by Lizhao on 2022/12/9.
//

#import "LLZCameraRecordProgressView.h"

@implementation LLZCameraRecordProgressView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    //设置圆心位置
    CGPoint center = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    //设置半径
    CGFloat radius = self.frame.size.width/2 - 2;
    //圆起点位置
    CGFloat startA = - M_PI_2;
    //圆终点位置
    CGFloat endA = -M_PI_2 + M_PI * 2 * _progress/self.total;
    
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:startA endAngle:endA clockwise:YES];
    
    //设置线条宽度
    CGContextSetLineWidth(ctx, 4);
    //设置描边颜色
    [[UIColor grayColor] setStroke];
    //把路径添加到上下文
    CGContextAddPath(ctx, path.CGPath);
    
    CGContextStrokePath(ctx);
}

- (void)setProgress:(CGFloat)progress{
    _progress = progress;
    [self setNeedsDisplay];
}

@end

