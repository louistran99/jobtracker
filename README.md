# Job Tracker

Requires Xcode 26. Run these commands from the project directory.

## Create the project

`make bootstrap` downloads XcodeGen and SwiftLint into `Tools/`.

`make generate` writes `JobTracker.xcodeproj` from `project.yml`.

## Run the app

Open `JobTracker.xcodeproj` in Xcode and run the JobTracker scheme.

`make test` runs the Swift package unit tests. `make ui-test` builds the app and runs the UI tests on the iPhone 17 simulator. Pass `UI_TEST_DESTINATION="platform=iOS Simulator,name=<device>"` to use another device. `make lint` runs SwiftLint and swift-format.
