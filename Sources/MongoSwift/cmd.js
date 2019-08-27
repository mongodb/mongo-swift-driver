const agg = {
    aggregate: 1,
    pipeline: [
        { "$changeStream": { "allChangesForCluster": true } },
        { "$project": { _id: 0 } }
    ],
    cursor: {}
};

let admin = db.getSiblingDB("admin");

const response = db.getSiblingDB("admin").runCommand(agg);
const cursor_id = response.cursor.id;

const get_more = {
    getMore: cursor_id,
    collection: "$cmd.aggregate",
};

db.mycoll.insertOne({});

admin.runCommand({
    configureFailPoint: "failCommand",
    mode: { times: 1 },
    data: {
        failCommands: ["getMore"],
        errorCode: 280
    }
});

print(JSON.stringify(db.getSiblingDB("admin").runCommand(get_more)));

