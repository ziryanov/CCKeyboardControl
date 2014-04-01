CCKeyboardControl
=================

CCKeyboardControl allows you to easily enable interactive dismissing of keyboard. Also it provides a simple way to add keyboard dependant animations.

![](https://github.com/ziryanov/CCKeyboardControl/raw/master/3.gif)

## Installation

[CocoaPods](http://cocoapods.org) is the recommended way to add `CCKeyboardControl` to your project.

Here's an example **podfile** that installs `CCKeyboardControl`.

###Podfile

```ruby
platform :ios, '6.0'

pod 'CCKeyboardControl'
```
## Usage

Example project included (CCKeyboardControlExample)

### Adding pan-to-dismiss (functionality introduced in iMessages)

```objective-c
__weak typeof(self) wself = self;
[self.view addKeyboardPanningWithFrameBasedActionHandler:^(CGRect keyboardFrameInView, CCKeyboardControlState keyboardState) {
    if (keyboardState != CCKeyboardControlStatePanning)
        [wself updateTableViewInsetWithKeyboardFrame:keyboardFrameInView];
} constraintBasedActionHandler:^(CGRect keyboardFrameInView, CCKeyboardControlState keyboardState) {
    wself.bottomPanelBottomConstraint.constant = wself.view.height - keyboardFrameInView.origin.y;
}];
```

## Notes

### Keyboard Delay On First Appearance
Standard iOS issue. Use Brandon William's [UIResponder category](https://github.com/mbrandonw/UIResponder-KeyboardCache) to cache the keyboard before first use.

### Automatic Reference Counting (ARC) support
ССKeyboardControl was made with ARC enabled by default.
