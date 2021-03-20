#  README

## prerequisites

muter v15
```
git clone https://github.com/muter-mutation-testing/muter.git
cd muter
make install
```

## before committing

`swiftformat **/* --swiftversion 5.1.3 --self insert`

TODO:

- [x] fix degenerate triangles
- [x] square line caps
- [x] draw multiple beziers on screen at once
- [x] per-instance bezier colors
- [x] quadratic bezier tesselator
- [x] cubic bezier tesselator
- [x] add touch handlers to store beziers from user input
- [x] put in multiple beziers into tesselator at once
- [x] red-green-blue color picker
- [x] figure out UIKit-SwiftUI interop
- [x] clear screen feature
- [x] clicks on SwiftUI elements bleed through to the underlying drawing touch handlers
    - [x] how do you declare an associative array in Swift? each view needs a unique key
    - [x] need a way to make blue SwiftUI rects disappear when popover shuts
- [x] line width UI
- [x] add more colors to color picker
- [x] playback
- [x] pan feature

- [x] audio recording
- [x] audio playback

- [x] no end cap bug: caps are not perfectly normal to start/end line segments

- [x] round line caps
- [x] identify hook on pen missing, use it to push a `PenUp`

- [ ] zoom feature
- [ ] handle screen rotation correctly
- [ ] undo feature

- [x] color picker
- [x] video export feature
- [ ] playback multiple layers

- [ ] allow viewer to pan away from where the playback panning position is, without stopping playback (Erin asked for this one) 
- [ ] allow user to change background color, consider eliminating lightest and darkest colors from palette

app util idea: color picker that stores colors into CSV for you!
- you click once, it stores the color, dumps a CSV into the clipboard when you ask it to
