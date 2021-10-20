require 'xcodeproj'

project = Xcodeproj::Project.open('mongo-swift-driver.xcodeproj')
targets = project.native_targets

# make a file reference for the provided project with file at dirPath (relative)
def make_reference(project, path)
    fileRef = project.new(Xcodeproj::Project::Object::PBXFileReference)
    fileRef.path = path
    return fileRef
end

mongoswift_tests_target = targets.find { |t| t.uuid == "mongo-swift-driver::TestsCommon" }
auth = make_reference(project, "./Tests/Specs/auth")
crud = make_reference(project, "./Tests/Specs/crud")
cm = make_reference(project, "./Tests/Specs/command-monitoring")
read_write_concern = make_reference(project, "./Tests/Specs/read-write-concern")
retryable_writes = make_reference(project, "./Tests/Specs/retryable-writes")
retryable_reads = make_reference(project, "./Tests/Specs/retryable-reads")
change_streams = make_reference(project, "./Tests/Specs/change-streams")
dns_seedlist = make_reference(project, "./Tests/Specs/initial-dns-seedlist-discovery")
auth = make_reference(project, "./Tests/Specs/auth")
transactions = make_reference(project, "./Tests/Specs/transactions")
convenient_transactions = make_reference(project, "./Tests/Specs/convenient-transactions")
uri_options = make_reference(project, "./Tests/Specs/uri-options")
conn_string = make_reference(project, "./Tests/Specs/connection-string")
unified = make_reference(project, "./Tests/Specs/unified-test-format")
versioned_api = make_reference(project, "./Tests/Specs/versioned-api")
sessions = make_reference(project, "./Tests/Specs/sessions")
mongoswift_tests_target.add_resources([
    auth,
    crud,
    cm,
    read_write_concern,
    retryable_writes,
    retryable_reads,
    change_streams,
    dns_seedlist,
    auth,
    transactions,
    convenient_transactions,
    uri_options,
    conn_string,
    unified,
    versioned_api,
    sessions
])

project.save
