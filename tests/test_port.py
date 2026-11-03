import importlib.machinery
import importlib.util
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT/path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


image = load('image_check', Path('scripts/validate-image.py'))
mesh = load('mesh', Path('overlay-rg35xxsp/usr/local/bin/mesh-console'))
gamepad = load('gamepad', Path('overlay-rg35xxsp/usr/local/bin/sp-gamepad'))


class PortTests(unittest.TestCase):
    def config(self, **env):
        base = {k:v for k,v in os.environ.items() if k not in ('TARGET','PANEL','RG_WORK','PROFILE')}
        return subprocess.run([str(ROOT/'build.sh'),'config'], env={**base, **env}, text=True, capture_output=True)

    def test_target_isolation_and_variants(self):
        h, sp, v2 = self.config(), self.config(TARGET='rg35xxsp'), self.config(TARGET='rg35xxsp',PANEL='v2')
        for result in (h,sp,v2): self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('rg35xx-h.dtb',h.stdout)
        self.assertIn('rg35xx-sp.dtb',sp.stdout)
        self.assertIn('rg35xx-sp-v2-panel.dtb',v2.stdout)
        paths = [next(x for x in r.stdout.splitlines() if x.startswith('WORK=')) for r in (h,sp,v2)]
        self.assertEqual(len(set(paths)),3)

    def test_reject_unknown_target_and_wrong_panel(self):
        for env in ({'TARGET':'../bad'}, {'TARGET':'rg35xxsp','PANEL':'rev6'}, {'RG_WORK':'/dev/sda'}):
            self.assertNotEqual(self.config(**env).returncode,0)

    def test_mbr_reject_out_of_bounds_and_missing_spl(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'test.img'
            mbr = bytearray(512)
            mbr[510:] = b'\x55\xaa'
            struct.pack_into('<I',mbr,440,1234)
            struct.pack_into('<B3sB3sII',mbr,446,0x80,b'\0'*3,0x0c,b'\0'*3,32768,524288)
            struct.pack_into('<B3sB3sII',mbr,462,0,b'\0'*3,0x83,b'\0'*3,557056,2048)
            with p.open('wb') as f:
                f.write(mbr); f.truncate(559104*512)
            with self.assertRaisesRegex(ValueError,'SPL'): image.validate(p)
            with p.open('r+b') as f:
                f.seek(8196); f.write(b'eGON.BT0')
            image.validate(p)
            with p.open('r+b') as f: f.truncate(558000*512)
            with self.assertRaisesRegex(ValueError,'fora'): image.validate(p)

    def test_serial_requires_unambiguous_selection(self):
        with patch.object(mesh,'ports',return_value=['/dev/a','/dev/b']):
            with self.assertRaises(ValueError): mesh.connection()
        self.assertEqual(mesh.connection(ble='node'),['--ble','node'])

    def test_cancelled_send_never_invokes_client(self):
        with patch('sys.argv',['mesh-console','--ble','node','send']), \
             patch('builtins.input',side_effect=['^all','prova','NO']), \
             patch.object(mesh.subprocess,'run') as run:
            mesh.main()
            run.assert_not_called()

    def test_empty_message_never_invokes_client(self):
        with patch('sys.argv',['mesh-console','--ble','node','send']), \
             patch('builtins.input',side_effect=['^all','']), \
             patch.object(mesh.subprocess,'run') as run:
            with self.assertRaises(ValueError): mesh.main()
            run.assert_not_called()

    def test_dpad_press_release_and_opposite_keys(self):
        state = gamepad.Directions()
        state.keys.add('left'); self.assertEqual(state.move(),(-4,0))
        state.keys.add('right'); self.assertEqual(state.move(),(0,0))
        state.keys.clear(); self.assertEqual(state.move(),(0,0))


if __name__ == '__main__': unittest.main()
