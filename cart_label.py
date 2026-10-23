"""Render the heartsoul XCF label with the installed mod's version (GIMP 3)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
FONT_NAME = 'Cascadia Mono Roman'
MAX_BYTES = 1024 * 1024


def render_in_gimp(request_path):
    """Called by GIMP's Python batch interpreter, not the host Python."""
    from gi.repository import Gimp, Gio
    from xml.etree import ElementTree as ET

    request = json.loads(Path(request_path).read_text())
    image = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(request['source']))
    if image is None:
        raise RuntimeError('Could not load the label XCF')
    try:
        groups = [l for l in image.get_layers() if l.get_name() == 'heartsoul' and l.is_group()]
        if len(groups) != 1:
            raise ValueError('Expected exactly one top-level heartsoul group')
        group = groups[0]

        def walk(layers):
            for layer in layers:
                yield layer
                if layer.is_group():
                    yield from walk(layer.get_children())

        matches = [l for l in walk(group.get_children()) if l.get_name() == 'MOD_VERSION_NUMBER']
        if len(matches) != 1 or not isinstance(matches[0], Gimp.TextLayer):
            raise ValueError('Expected one editable MOD_VERSION_NUMBER inside heartsoul')
        layer = matches[0]
        font = Gimp.Font.get_by_name(FONT_NAME)
        if font is None:
            raise ValueError('Bundled Cascadia Mono Roman font was not loaded')
        _, x, y = layer.get_offsets()
        box_width, box_height = layer.get_width(), layer.get_height()
        right, bottom = x + box_width, y + box_height
        source_text_bounds = [x, y, right, bottom]
        font_size, unit = layer.get_font_size()
        markup = layer.get_markup()
        if markup:
            tree = ET.fromstring(markup)
            count = 0
            for element in tree.iter():
                if 'font' in element.attrib:
                    element.set('font', FONT_NAME)
                for attr in ('text', 'tail'):
                    value = getattr(element, attr)
                    if value:
                        value, n = re.subn(r'\d+\.\d+\.\d+', request['version'], value)
                        count += n
                        setattr(element, attr, value)
            if count != 1:
                raise ValueError('Version layer must contain exactly one semantic version')
            text = ''.join(tree.itertext())
        else:
            text, count = re.subn(r'\d+\.\d+\.\d+', request['version'], layer.get_text() or '')
            if count != 1:
                raise ValueError('Version layer must contain exactly one semantic version')
        # The source uses a fixed text box. Cascadia has taller line metrics than
        # Consolas; measure a dynamic text layer so the version cannot wrap out
        # of that box and disappear. Fit longer future versions the same way.
        measure = Gimp.TextLayer.new(image, text, font, font_size, unit)
        image.insert_layer(measure, None, 0)
        try:
            for attempt in range(12):
                measure.set_font_size(font_size, unit)
                if markup:
                    measure.set_markup(ET.tostring(tree, encoding='unicode'))
                width, height = measure.get_width(), measure.get_height()
                if width <= box_width and height <= box_height:
                    break
                scale = min(box_width / width, box_height / height) * 0.995
                font_size *= scale
                if markup:
                    for element in tree.iter():
                        if 'size' in element.attrib:
                            element.set('size', str(max(1, int(int(element.get('size')) * scale))))
            else:
                raise ValueError('Could not fit the version text into its source box')
        finally:
            image.remove_layer(measure)
        if not layer.set_font(font) or not layer.set_font_size(font_size, unit):
            raise RuntimeError('Could not set version font')
        if markup:
            if not layer.set_markup(ET.tostring(tree, encoding='unicode')):
                raise RuntimeError('Could not update version text/font')
        else:
            if not layer.set_text(text):
                raise RuntimeError('Could not update version text/font')
        layer.resize(width, height)
        layer.set_name('MOD_VERSION_NUMBER')
        # Preserve the lower-right anchor even when the number of digits changes.
        x, y = right - layer.get_width(), bottom - layer.get_height()
        if x < 0 or y < 0 or right > image.get_width() or bottom > image.get_height():
            raise ValueError('Updated version text would leave the label canvas')
        layer.set_offsets(x, y)
        for top in image.get_layers():
            top.set_visible(top == group)
        # Keep every child visibility, blend mode and cached artwork as authored.
        parent = layer
        while parent is not None:
            parent.set_visible(True)
            parent = parent.get_parent()
        procedure = Gimp.get_pdb().lookup_procedure('file-png-export')
        config = procedure.create_config()
        for key, value in {
            'run-mode': Gimp.RunMode.NONINTERACTIVE, 'image': image,
            'file': Gio.File.new_for_path(request['output']), 'compression': 9,
            'time': False, 'phys': False, 'bkgd': False,
            'include-color-profile': False, 'include-thumbnail': False,
            'include-exif': False, 'include-iptc': False, 'include-xmp': False,
            'include-comment': False,
        }.items():
            config.set_property(key, value)
        result = procedure.run(config)
        if result.index(0) != Gimp.PDBStatusType.SUCCESS:
            raise RuntimeError('PNG export failed: ' + str(result.index(0)))
        Path(request['report']).write_text(json.dumps({
            'version': request['version'], 'font': font.get_name(),
            'text': ''.join(ET.fromstring(layer.get_markup()).itertext()) if layer.get_markup() else layer.get_text(),
            'canvas': [image.get_width(), image.get_height()],
            'text_bounds': [x, y, right, bottom],
            'source_text_bounds': source_text_bounds,
        }, indent=2) + '\n')
    finally:
        image.delete()


def render_label(version, output, *, source=None, gimp=None, refresh_art=False):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Expected a mod version such as 0.7.19')
    source = Path(source or ROOT / 'release/gbalabels.xcf').resolve()
    output = Path(output).resolve()
    if output == source:
        raise ValueError('Label output must not overwrite the source XCF')
    executable = gimp or os.environ.get('HNS_GIMP') or shutil.which('gimp') or shutil.which('gimp-3.0')
    if not executable:
        raise RuntimeError('GIMP 3 is required; set HNS_GIMP to its executable or AppImage')
    executable = str(Path(executable).resolve())
    output.parent.mkdir(parents=True, exist_ok=True)
    original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    artwork_path = ROOT / 'release/cart-label-artwork.png'
    artwork_record = ROOT / 'release/cart-label-artwork.json'
    if not refresh_art:
        artwork_info = json.loads(artwork_record.read_text())
        if artwork_info['source_sha256'] != original_hash:
            raise ValueError('XCF artwork changed; run cart_label.py --refresh-art and review the new artwork')
        if hashlib.sha256(artwork_path.read_bytes()).hexdigest() != artwork_info['png_sha256']:
            raise ValueError('The reviewed label artwork PNG does not match its recorded hash')
    with tempfile.TemporaryDirectory(prefix='hns-label-') as temporary:
        temp = Path(temporary)
        request = temp / 'request.json'
        report = temp / 'report.json'
        rendered = temp / 'label.png'
        request.write_text(json.dumps({'source': str(source), 'output': str(rendered),
                                       'version': version, 'report': str(report)}))
        gimprc = temp / 'gimprc'
        gimprc.write_text('(font-path ' + json.dumps(str(ROOT / 'release/fonts')) + ')\n(check-updates no)\n')
        command = 'import runpy; runpy.run_path(' + repr(str(Path(__file__).resolve())) + ')["render_in_gimp"](' + repr(str(request)) + ')'
        from xml.sax.saxutils import escape
        fontconfig = temp / 'fonts.conf'
        fontconfig.write_text('<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">'
                              '<fontconfig><dir>' + escape(str(ROOT / 'release/fonts')) + '</dir>'
                              '<cachedir>' + escape(str(temp / 'font-cache')) + '</cachedir></fontconfig>')
        env = {**os.environ, 'GEGL_THREADS': '1', 'GEGL_USE_OPENCL': 'no',
               'FONTCONFIG_FILE': str(fontconfig)}
        result = subprocess.run([executable, '-n', '-i', '-d', '--no-cpu-accel', '-g', str(gimprc),
                                 '--batch-interpreter=python-fu-eval', '-b', command, '--quit'],
                                capture_output=True, text=True, timeout=180, env=env)
        if result.returncode or not report.exists():
            raise RuntimeError('GIMP label render failed:\n' + result.stdout + result.stderr)
        metadata = json.loads(report.read_text())
        # Strip metadata and encode losslessly with deterministic PNG settings.
        from PIL import Image
        with Image.open(rendered) as image:
            rgba = image.convert('RGBA')
            if not refresh_art:
                # GEGL's live blend filters can vary by one RGB unit at a few
                # distant edge pixels. Keep the reviewed artwork exact and use
                # the fresh XCF render only inside the original version box.
                # Its hash guard prevents silently keeping art from an old XCF.
                with Image.open(artwork_path) as artwork:
                    composite = artwork.convert('RGBA')
                if composite.size != rgba.size:
                    raise ValueError('Reviewed artwork and XCF canvas sizes differ')
                box = tuple(artwork_info['version_box'])
                bounds = metadata['text_bounds']
                if bounds[0] < box[0] or bounds[1] < box[1] or bounds[2] > box[2] or bounds[3] > box[3]:
                    raise ValueError('Version text escaped its reviewed artwork box')
                composite.paste(rgba.crop(box), box)
                rgba = composite
            rgba.save(rendered, format='PNG', optimize=True, compress_level=9)
        label = rendered.read_bytes()
        if not label.startswith(b'\x89PNG\r\n\x1a\n') or len(label) > MAX_BYTES:
            raise ValueError('Cart label must be a PNG of at most 1 MiB')
        if hashlib.sha256(source.read_bytes()).hexdigest() != original_hash:
            raise RuntimeError('The source XCF changed during rendering')
        if refresh_art:
            artwork_path.write_bytes(label)
            artwork_record.write_text(json.dumps({
                'source_sha256': original_hash, 'png_sha256': hashlib.sha256(label).hexdigest(),
                'version_box': metadata['source_text_bounds'],
            }, indent=2) + '\n')
        output.write_bytes(label)
    return {**metadata, 'source_sha256': original_hash,
            'png_sha256': hashlib.sha256(label).hexdigest(), 'bytes': len(label)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', default=json.loads((ROOT / 'manifest.json').read_text())['version'])
    parser.add_argument('--out', type=Path, default=ROOT / 'release/pokemon-heart-soul.png')
    parser.add_argument('--source', type=Path)
    parser.add_argument('--gimp')
    parser.add_argument('--refresh-art', action='store_true', help='Refresh the reviewed artwork reference after editing the XCF')
    args = parser.parse_args()
    print(json.dumps(render_label(args.version, args.out, source=args.source, gimp=args.gimp, refresh_art=args.refresh_art), indent=2))
