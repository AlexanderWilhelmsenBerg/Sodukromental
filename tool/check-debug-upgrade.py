"""Exercise an in-place debug upgrade on a disposable, running Android emulator."""
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time

serial, upgrade = sys.argv[1:]
if not serial.startswith('emulator-'):
    raise SystemExit('An emulator serial is required.')
app = 'org.sodukromental.debug'
activity = f'{app}/org.sodukromental.MainActivity'
files = {'campaign': 'sodukromental_player.sqlite', 'library': 'sodukromental_library.sqlite'}

def adb(*args, data=None, **kwargs):
    return subprocess.run(['adb','-s',serial,*args], input=data, check=True, stdout=subprocess.PIPE,
                          timeout=180, **kwargs).stdout

def launch():
    adb('shell','am','start','-W','-n',activity)
    for attempt in range(60):
        found = adb('shell','run-as',app,'ls','app_flutter').decode()
        if all(filename in found.split() for filename in files.values()): return
        time.sleep(1)
    raise RuntimeError('The installed game did not create both SQLite files.')

def dbrows(path, name, data=None):
    table, key, value = ('snapshots','name','campaign') if name=='campaign' else ('progress','id','growth-5|authored-1')
    with sqlite3.connect(path) as db:
        if data is not None:
            db.execute(f'INSERT OR REPLACE INTO {table} ({key},body) VALUES (?,?)', (value,json.dumps(data)))
        return json.loads(db.execute(f'SELECT body FROM {table} WHERE {key}=?',(value,)).fetchone()[0])

def contents(name):
    return adb('exec-out','run-as',app,'cat','app_flutter/'+name)

def snapshot(folder):
    for filename in files.values():
        for suffix in ('','-wal'):
            name=filename+suffix
            if name in adb('shell','run-as',app,'ls','app_flutter').decode().split():
                (folder/name).write_bytes(contents(name))

def run():
    with tempfile.TemporaryDirectory() as working:
        folder = Path(working)
        launch()
        adb('shell','am','force-stop',app)
        snapshot(folder)
        pair=json.loads(subprocess.check_output(['dart','--packages=.dart_tool/package_config.json','tool/upgrade_fixture.dart']))
        for key,filename in files.items():
            dbrows(folder/filename,key,pair[key])
            # Close all writers and checkpoint before transferring standalone files.
            with sqlite3.connect(folder/filename) as db: db.execute('PRAGMA wal_checkpoint(TRUNCATE)').fetchall()
            adb('shell','run-as',app,'rm','-f','app_flutter/'+filename+'-wal','app_flutter/'+filename+'-shm')
            adb('shell','run-as',app,'sh','-c',f"'cat > app_flutter/{filename}'",data=(folder/filename).read_bytes())
        launch()
        adb('shell','am','force-stop',app)
        result=adb('install','-r',upgrade).decode()
        if 'Success' not in result: raise RuntimeError(result)
        launch()
        adb('shell','am','force-stop',app)
        after=folder/'after'
        after.mkdir()
        snapshot(after)
        preserved={key:dbrows(after/file,key) for key,file in files.items()}
        state=folder/'restored.json'
        state.write_text(json.dumps(preserved))
        subprocess.run(['dart','--packages=.dart_tool/package_config.json','tool/upgrade_fixture.dart','verify',str(state)],check=True)
        print(adb('shell','dumpsys','package',app).decode().split('versionCode=',1)[1].splitlines()[0])
if __name__=='__main__':run()
