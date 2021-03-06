//
//  ViewController.m
//  voucher_swap
//
//  Created by Brandon Azad on 12/7/18.
//  Copyright © 2018 Brandon Azad. All rights reserved.
//

#import "ViewController.h"
#import "kernel_slide.h"
#import "voucher_swap.h"
#import "kernel_memory.h"
#import <mach/mach.h>
#include "post.h"
#include <sys/utsname.h>
#include "Extension.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *outPutWindow;
@property (weak, nonatomic) IBOutlet UIButton *runButton;
@property (weak, nonatomic) IBOutlet UIButton *openFileManager;

@end

@implementation ViewController

@synthesize myButton;

- (bool)voucher_swap {
    vm_size_t size = 0;
    host_page_size(mach_host_self(), &size);
    if (size < 16000) {
        printf("non-16K devices are not currently supported.\n");
        return false;
    }
    voucher_swap();
    if (!MACH_PORT_VALID(kernel_task_port)) {
        printf("tfp0 is invalid?\n");
        return false;
    }
    return true;
}

- (void)failure {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"failed" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)go:(id)sender {
    
    [_runButton setEnabled:NO];
    
    Post *post = [[Post alloc] init];
    static int progress = 0;
    if (progress == 2) {
        [post respring];
        return;
    }
    if (progress == 1) {
	return;
    }
    progress++;
    bool success = [self voucher_swap];
    if (success) {
	sleep(1);
        [post go];
        [sender setTitle:@"respring" forState:UIControlStateNormal];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"success" message:[NSString stringWithFormat:@"tfp0: %i\nkernel base: 0x%llx\nuid: %i\nunsandboxed: true", kernel_task_port, kernel_slide + 0xFFFFFFF007004000, getuid()] preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"done" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self failure];
    }
    progress++;
    
    [_runButton setEnabled:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (isRootNow()) {
        _outPutWindow.text = readOutPutString();
        [_runButton setEnabled:NO];
        return;
    }
    // Do any additional setup after loading the view, typically from a nib.
    
//    if (offsets_init() != 0) {
//        _outPutWindow.text = @"Offsets init may be failed.\n";
//    }
    
    struct utsname u = {};
    uname(&u);
    //    struct    utsname {
    //        char    sysname[_SYS_NAMELEN];    /* [XSI] Name of OS */
    //        char    nodename[_SYS_NAMELEN];    /* [XSI] Name of this network node */
    //        char    release[_SYS_NAMELEN];    /* [XSI] Release level */
    //        char    version[_SYS_NAMELEN];    /* [XSI] Version level */
    //        char    machine[_SYS_NAMELEN];    /* [XSI] Hardware type */
    //    };
    NSString *deviceInfo = [[NSString alloc] initWithFormat:@"\n\n%s\n\n%s -- %s", u.version, u.nodename, u.machine];
    _outPutWindow.text = [[_outPutWindow text] stringByAppendingString: deviceInfo];
    
    setUserLandHome([NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,    NSUserDomainMask, YES)objectAtIndex:0]);
    //    [NSFileManager defaultManager]
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch * touch = [touches anyObject];
    if(touch.phase == UITouchPhaseBegan) {
        [_outPutWindow resignFirstResponder];
    }
}

@end

@interface FileManagerViewController () <UITableViewDelegate,UITableViewDataSource> {
    
    NSString *currentPath;
    NSString *copyFilePath;
    NSString *copyFileName;
    NSArray *currentFileList;
}

@property (weak, nonatomic) IBOutlet FileListTableView *tableView;
@property (weak, nonatomic) IBOutlet UITextField *URLText;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;


@end


@implementation FileManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    currentPath = @"/";
    currentFileList = catchContentUnderPath(@"/");
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 1.0; //seconds
    lpgr.delegate = self;
    [self.tableView addGestureRecognizer:lpgr];
    
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch * touch = [touches anyObject];
    if(touch.phase == UITouchPhaseBegan) {
        [_URLText resignFirstResponder];
    }
}

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    if (indexPath == nil) {
        NSLog(@"long press on table view but not on a row");
    } else if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        NSLog(@"long press on table view at row %ld", indexPath.row);
        NSString *thisFileName = currentFileList[indexPath.row];
        NSString *thisFilePath;
        if ([currentPath isEqualToString:@"/"]) {
            thisFilePath = [[NSString alloc] initWithFormat:@"%@%@", currentPath, currentFileList[indexPath.row]];
        }else{
            thisFilePath = [[NSString alloc] initWithFormat:@"%@/%@", currentPath, currentFileList[indexPath.row]];
        }
        
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Command?"
                                                                       message:@"This is an alert."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* copyAction = [UIAlertAction actionWithTitle:@"Copy it!" style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               self->_errorLabel.text = @"Touched to clip board.";
                                                               self->copyFileName = thisFileName;
                                                               self->copyFilePath = thisFilePath;
                                                           }];
        UIAlertAction* renameAction = [UIAlertAction actionWithTitle:@"Rename it!" style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action) {
                                                                 UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"Name?"
                                                                                                                                           message: nil
                                                                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                                                                 [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                                                                     textField.placeholder = @"name";
                                                                     textField.textColor = [UIColor blueColor];
                                                                     textField.clearButtonMode = UITextFieldViewModeWhileEditing;
                                                                     textField.borderStyle = UITextBorderStyleRoundedRect;
                                                                 }];
                                                                 [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                                     NSArray * textfields = alertController.textFields;
                                                                     UITextField * namefield = textfields[0];
                                                                     if ([namefield.text isEqualToString:@""]) {
                                                                         return;
                                                                     }
                                                                     NSString *destFilePath = [[dropLastContentOfSplash(thisFilePath) stringByAppendingString:@"/"] stringByAppendingString:thisFileName];
                                                                     NSError *errrrr;
                                                                     [[NSFileManager defaultManager] moveItemAtPath:thisFilePath toPath:destFilePath error:&errrrr];
                                                                     if (errrrr != nil) {
                                                                         printf("Soemthing wrong!\n");
                                                                         NSLog(@"%@", errrrr);
                                                                         self->_errorLabel.text = @"Failed to rename!";
                                                                     }
                                                                 }]];
                                                                 [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {NSLog(@"Canceled");}]];
                                                                 [self presentViewController:alertController animated:YES completion:nil];
                                                             }];
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
                                                             handler:nil];
        
        [alert addAction:copyAction];
        [alert addAction:renameAction];
        [alert addAction:cancelAction];
        [self presentViewController:alert animated:YES completion:nil];
        
    } else {
        NSLog(@"gestureRecognizer.state = %ld", gestureRecognizer.state);
    }
}
- (IBAction)goBack:(id)sender {
    if ([currentPath  isEqual: @"/"]) {
        _URLText.text = currentPath;
        return;
    }
    currentPath = dropLastContentOfSplash(currentPath);
    currentFileList = catchContentUnderPath(currentPath);
    _tableView.reloadData;
    _URLText.text = currentPath;
}

- (IBAction)refreshList:(id)sender {
    if (![[NSFileManager defaultManager] fileExistsAtPath:_URLText.text]) {
        _errorLabel.text = @"No such file or direct.";
        return;
    }
    currentPath = _URLText.text;
    if (isThisDirectory(currentPath)) {
        currentFileList = catchContentUnderPath(currentPath);
        _tableView.reloadData;
    }else{
        currentPath = dropLastContentOfSplash(currentPath);
        currentFileList = catchContentUnderPath(currentPath);
        _tableView.reloadData;
    }
}

- (IBAction)wentToHome:(id)sender {
    currentPath = dropLastContentOfSplash(readUserlandHome());
    currentFileList = catchContentUnderPath(currentPath);
    _tableView.reloadData;
    _URLText.text = currentPath;
}

- (IBAction)pasteFile:(id)sender {
    if ([copyFileName isEqualToString:@""] || copyFileName == nil) {
        _errorLabel.text = @"Nothing to copy!";
        return;
    }
    NSString *dest;
    if ([currentPath isEqualToString:@"/"]) {
        dest = [[NSString alloc] initWithFormat:@"%@%@", currentPath, copyFileName];
    }else{
        dest = [[NSString alloc] initWithFormat:@"%@/%@", currentPath, copyFileName];
    }
    while ([[NSFileManager defaultManager] fileExistsAtPath:dest]) {
        dest = [dest stringByAppendingString:@".copy"];
    }
    NSError *err;
    [[NSFileManager defaultManager] copyItemAtPath:copyFilePath toPath:dest error:&err];
    if (err != nil) {
        NSLog(@"Copy file failed!");
        _errorLabel.text = @"Unable to copy.";
    }
    currentFileList = catchContentUnderPath(currentPath);
    _tableView.reloadData;
}

- (IBAction)createFolder:(id)sender {
    _errorLabel.text = @"Last error: nil";
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"Name?"
                                                                              message: @"Input the folder's name or cancel."
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"name";
        textField.textColor = [UIColor blueColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray * textfields = alertController.textFields;
        UITextField * namefield = textfields[0];
        if ([namefield.text isEqualToString:@""]) {
            return;
        }
        NSLog(@"Creating file as:%@",namefield.text);
        NSError *err;
        NSString *fullPath;
        if ([self->currentPath isEqualToString:@"/"]) {
            fullPath = [[NSString alloc] initWithFormat:@"%@%@", self->currentPath, namefield.text];
        }else{
            fullPath = [[NSString alloc] initWithFormat:@"%@/%@", self->currentPath, namefield.text];
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:fullPath withIntermediateDirectories:NO attributes:nil error:&err];
        if (err != nil) {
            NSLog(@"%@", err);
            self->_errorLabel.text = @"Failed to create folder.";
        }
        self->currentFileList = catchContentUnderPath(self->currentPath);
        self->_tableView.reloadData;
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {NSLog(@"Canceled");}]];
    [self presentViewController:alertController animated:YES completion:nil];
}


- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    static NSString *cellID = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    cell.textLabel.text = [@"  " stringByAppendingString: currentFileList[indexPath.row]];
    NSString *fullPathForThisFile;
    if ([currentPath isEqualToString:@"/"]){
        fullPathForThisFile = [[NSString alloc] initWithFormat:@"%@%@", currentPath, currentFileList[indexPath.row]];
    }else{
        fullPathForThisFile = [[NSString alloc] initWithFormat:@"%@/%@", currentPath, currentFileList[indexPath.row]];
    }
    if (isThisDirectory(fullPathForThisFile)) {
        int itemCount = countItemInThePath(fullPathForThisFile);
        NSString *details = [[NSString alloc] initWithFormat:@"%d item(s)", itemCount];
        cell.detailTextLabel.text = details;
    }else{
        cell.detailTextLabel.text = @"";
    }
    
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return currentFileList.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *fullPathForThisFile;
    
    NSError *err;
    NSDictionary *attr=[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0777U] forKey:NSFilePosixPermissions];
    [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:fullPathForThisFile error:&err];
    NSLog(@"%@", err);
    
    if ([currentPath  isEqual: @"/"]) {
        fullPathForThisFile = [[NSString alloc] initWithFormat:@"%@%@", currentPath, currentFileList[indexPath.row]];
    }else{
        fullPathForThisFile = [[NSString alloc] initWithFormat:@"%@/%@", currentPath, currentFileList[indexPath.row]];
    }
    if (isThisDirectory(fullPathForThisFile)) {
        currentPath = fullPathForThisFile;
        currentFileList = catchContentUnderPath(currentPath);
        tableView.reloadData;
        _URLText.text = currentPath;
    }else{
        NSString *filePath = [readUserlandHome() stringByAppendingPathComponent:currentFileList[indexPath.row]];
        if (isRootNow()) {
            self->_errorLabel.text = @"We can't share file as root.\nBut we copied it to /var/mobile/Media/.";
            NSString *destPath = [@"/var/mobile/Media/" stringByAppendingPathComponent:currentFileList[indexPath.row]];
            [[NSFileManager defaultManager] copyItemAtPath:filePath toPath:destPath error:&err];
            NSLog(@"%@", err);
            if (err != nil) {
                _errorLabel.text = @"Failed to copy to /var/mobile/Media/";
                NSURL *fileUrl = [NSURL fileURLWithPath:fullPathForThisFile];
                NSData *fileData = [NSData dataWithContentsOfURL:fileUrl];
                NSURL *url2 = [[NSURL alloc] initWithString:destPath];
                [fileData writeToURL:url2 atomically:YES];
                NSString *fileDataString = [[NSString alloc] initWithContentsOfFile:fullPathForThisFile encoding:NSUTF8StringEncoding error:nil];
                NSLog(@"%@", fileDataString);
            }
            NSDictionary *attr=[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0777U] forKey:NSFilePosixPermissions];
            [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:destPath error:&err];
            NSLog(@"%@", err);
        }else{
            // Let's copy file to our doc direct.
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            [[NSFileManager defaultManager] copyItemAtPath:fullPathForThisFile toPath:filePath error:nil];
            NSDictionary *attr=[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0777U] forKey:NSFilePosixPermissions];
            [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:filePath error:&err];
            NSLog(@"%@", err);
            
            NSURL *fileUrl     = [NSURL fileURLWithPath:filePath isDirectory:NO];
            NSArray *activityItems = @[fileUrl];
            UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            //if iPhone
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                [self presentViewController:activityController animated:YES completion:nil];
            }
            //if iPad
            else {
                // Change Rect to position Popover
                UIPopoverController *popup = [[UIPopoverController alloc] initWithContentViewController:activityController];
                [popup presentPopoverFromRect:CGRectMake(self.view.frame.size.width/2, self.view.frame.size.height/4, 0, 0)inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            }
        }
        
    }
    
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    _errorLabel.text = @"Last error: nil";
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *fullPathForThisFile;
        if ([currentPath  isEqual: @"/"]) {
            fullPathForThisFile = [[NSString alloc] initWithFormat:@"%@%@", currentPath, currentFileList[indexPath.row]];
        }else{
            fullPathForThisFile = [[NSString alloc] initWithFormat:@"%@/%@", currentPath, currentFileList[indexPath.row]];
        }
        NSError *err;
        [[NSFileManager defaultManager] removeItemAtPath:fullPathForThisFile error:&err];
        if (err != nil) {
            NSLog(@"%@", err);
            _errorLabel.text = @"Failed to delete file.";
        }
        currentFileList = catchContentUnderPath(currentPath);
        tableView.reloadData;
    }
}


@end
