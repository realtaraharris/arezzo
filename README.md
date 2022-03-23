# README

This is an iPad app that lets you record and play back drawing with audio on a pannable canvas. The idea is to provide the basis for the creation of interactive workbooks that help people learn things.

The canvas is rendered using Metal, and the audio recording and playback are done using the Core Audio APIs. The UI is done in UIKit.  I wasted a lot of time trying to make SwiftUI work, but it simply isn't an option until Apple gives up enough control to make it work.

I recently spilled a latte into my six-month-old MacBook Pro, (and Apple refuses to supply Rossmann with parts to fix it) so I don't have a machine to build this on at the moment.

Swift is not my native tongue, and this whole thing is pretty experimental. Maybe you will help breathe more life into this thing ❤

## license

BSD

## prerequisites

muter v15
```
git clone https://github.com/muter-mutation-testing/muter.git
cd muter
make install
```

## before committing

`swiftformat **/* --swiftversion 5.1.3 --self insert`
