# Job Tracker

Requires Xcode 26. Run these commands from the project directory.

## Create the project

`make bootstrap` downloads XcodeGen and SwiftLint into `Tools/`.

`make generate` writes `JobTracker.xcodeproj` from `project.yml`.

## Run the app

Open `JobTracker.xcodeproj` in Xcode and run the JobTracker scheme.

`make test` lints the code, runs the Swift tests, and builds the app for the simulator.
