#import "DualKeyboardManager+SingleInstance.h"
#import <sys/file.h>
#import <errno.h>
#import <objc/runtime.h>

static void *LockFileDescriptorKey = &LockFileDescriptorKey;

@implementation DualKeyboardManager (SingleInstance)

- (void)setLockFd:(int)fd {
    objc_setAssociatedObject(self, LockFileDescriptorKey, @(fd), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (int)lockFd {
    NSNumber *fd = objc_getAssociatedObject(self, LockFileDescriptorKey);
    return fd ? [fd intValue] : -1;
}

- (BOOL)ensureSingleInstance {
    int fd = open("/tmp/dual.lock", O_CREAT | O_RDWR, 0600);
    if (fd == -1) {
        if (!self.quietMode) {
            fprintf(stderr, "Failed to open lock file: %s\n", strerror(errno));
        }
        return NO;
    }
    
    if (flock(fd, LOCK_EX | LOCK_NB) == -1) {
        if (errno == EWOULDBLOCK) {
            if (!self.quietMode) {
                fprintf(stderr, "Another instance of DualKeyboard is already running\n");
            }
            close(fd);
            return NO;
        }
        if (!self.quietMode) {
            fprintf(stderr, "Failed to lock file: %s\n", strerror(errno));
        }
        close(fd);
        return NO;
    }
    
    [self setLockFd:fd];
    return YES;
}

- (void)cleanupSingleInstance {
    int fd = [self lockFd];
    if (fd > 0) {
        flock(fd, LOCK_UN);
        close(fd);
        unlink("/tmp/dual.lock");
        [self setLockFd:-1];
    }
}

@end