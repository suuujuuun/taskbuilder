import SwiftData
import Foundation

let url = URL(fileURLWithPath: "/tmp/test.sqlite")
let schema = Schema([])
let conf1 = ModelConfiguration(url: url)
let conf2 = ModelConfiguration("Test", schema: schema)
