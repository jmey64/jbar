import Foundation

let runner = TestRunner.shared
runner.addSuite(DynamicWidthLayoutTests.suite())
runner.addSuite(TaskbarItemTests.suite())
runner.addSuite(QuickLaunchServiceTests.suite())
runner.addSuite(AppIndexServiceTests.suite())

let success = runner.run()
exit(success ? 0 : 1)
