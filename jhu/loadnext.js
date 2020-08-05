var path = require('path')
var db = require(path.join(__dirname, '../src/db'))


async function load() {
    let client;
    try {
        client = await db.getClient()
	    while(true) {
	        console.log('start loading...');
            let result = (await client.query('select jhu.load_next_day()')).rows[0].load_next_day;
	        if(result.code === 16908805) {
		        break;
	        }
	        console.log("result:",result);
	    }
    }
    catch (err) {
        throw err;
    }
    finally {
        if (client != null) {
            client.release()
        }
    }
}
;(async () => {
    try {
        await load();
	process.exit(1);
    }
    catch(err) {
        throw err;
    }
})();

