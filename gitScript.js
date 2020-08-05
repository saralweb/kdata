let path = require('path');
let fs = require('fs');
let nodegit = require('nodegit');
let repoFolder = path.resolve(__dirname, '.git');
let dirNames = ['ctind','generated'];

async function main() {
    try {
        let repo = await nodegit.Repository.open(repoFolder);
        let filepaths = await gitStatus(repo);
        let filteredPath = filterFilePaths(filepaths);
        console.log(filteredPath);
        let oid = await gitAdd(repo,filteredPath);
        let commitId = await gitCommit(repo,oid);
        console.log('New Commit Id :',commitId);
        await gitPush(repo);
    }
    catch(err) {
        throw err;
    }
}

function filterFilePaths(filepaths) {
    let filtered = [];
    filepaths.forEach((filepath) => {
        let filesToStage = filepath.split('/')[0];
        dirNames.forEach((dirName) =>{
            if(filesToStage === dirName) {
                filtered.push(filepath);
            }
        })
    })
    return filtered;
}

async function gitPush(repo) {
    try{
        let refs = ["refs/heads/master:refs/heads/master"];
        let remote = await nodegit.Remote.lookup(repo,'origin');
        let fetchOpts = {
          callbacks: {
            certificateCheck: function() {
                return 0;
            },
            credentials: function(url, userName) {
                try {
                    let creds = JSON.parse(fs.readFileSync(path.join(__dirname, 'git_credentials.json')));
                    return nodegit.Cred.userpassPlaintextNew(creds.username,creds.password);
                }
                catch(err) {
                    throw err;
                }
            },
            pushTransferProgress: function() {
              wasCalled = true;
            }
          }
        };
        await remote.push( refs,fetchOpts)
        console.log('Done!')
    }
    catch(err) {
        throw err;
    }
}

async function gitCommit(repo,oid) {
    try {
        let creds = JSON.parse(fs.readFileSync(path.join(__dirname, 'git_credentials.json')));
        let head  = await nodegit.Reference.nameToId(repo, 'HEAD');
        let parent = await repo.getCommit(head);
        let author = await nodegit.Signature.now(creds.authorName, creds.authorId);
        let committer = await nodegit.Signature.now(creds.committerName, creds.committerId);
        let message = `data set generated for ${dateConverter(new Date())}`;
        console.log(message);
        let commitId = await  repo.createCommit('HEAD', author, committer,message, oid, [parent]);
        return commitId;
    }
    catch(err) {
        throw err;
    }
}

async function gitAdd(repo,filespath) {
    try {
        let index = await repo.index();
        for(let i=0; i< filespath.length; i++) {
            await index.addByPath(filespath[i]);
        }
        await index.write();
        let oid = await index.writeTree();
        return oid;
    }
    catch(err) {
        throw err;
    }
}

async function gitStatus(repo) {
    try {
        let filepaths = []
        let statuses = await repo.getStatus();
        statuses.forEach(function(file) {
            filepaths.push(file.path());
            console.log(statusToText(file) + ': ' +file.path());
        });
        return filepaths;
    }
    catch(err) {
        throw err;
    }
}
function statusToText(status) {
    var words = [];
    if (status.isNew()) { words.push('NEW'); }
    if (status.isModified()) { words.push('MODIFIED'); }
    if (status.isTypechange()) { words.push('TYPECHANGE'); }
    if (status.isRenamed()) { words.push('RENAMED'); }
    if (status.isIgnored()) { words.push('IGNORED'); }
    return words.join(' ');
}
function dateConverter(date) {
    if(date.getTimezoneOffset() === 0) {
        let indiaTime = new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' } );
        date = new Date(indiaTime);
    }
    return date;
}
main();
