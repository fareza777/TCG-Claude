"""Conservative ability-package audit; basic resource cards are intentional reprints.

Names, art, flavor, printed unit stats and costs are not abilities. Equivalent
implicit JSON defaults and color-swapped abilities compare equally. For legacy
unconstrained CHOOSE selectors, printed target restrictions are used so an old
schema's missing fields cannot conceal a reprint. Trigger and operation order,
actual effect numbers, target scope and combat keywords remain significant.
"""
import argparse
import collections
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COLORS = {'VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM'}


def normalize(value):
    if isinstance(value, str):
        value = value.upper()
        return 'COLOR' if value in COLORS else value
    if isinstance(value, list):
        return [normalize(v) for v in value]
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in value.items()}
    return value


def signature(card):
    blocks = copy.deepcopy(card.get('effects') or [])
    text = card.get('text', '').lower()
    for block in blocks:
        for effect in block.get('effects', []):
            if effect.get('counter') == 'PLUS1':
                effect.pop('counter')
            if effect.get('op') in ('GAIN_AETHER', 'CREATE_TOKEN'):
                effect.setdefault('amount', 1)
            if effect.get('op') == 'SEARCH_DECK':
                effect.setdefault('destination', 'HAND')
            t = effect.get('target')
            if t:
                if t.get('zone') == 'ARENA':
                    t.pop('zone')
                if t.get('select') == 'CHOOSE':
                    t.setdefault('owner', 'OPPONENT' if 'target enemy' in text else
                                 'SELF' if ('target friendly' in text or
                                            'target unit you control' in text) else 'ANY')
                    t.setdefault('filter', {'type': 'UNIT_OR_PLAYER' if 'any target' in text else 'UNIT'})
                if t.get('filter', {}).get('excludeSelf') is False:
                    t['filter'].pop('excludeSelf')
            token = effect.get('token')
            if token:
                token.pop('name', None)
                token.pop('subtype', None)
                token['keywords'] = sorted(k.upper() for k in token.get('keywords', []))
                token.setdefault('might', 1)
                token.setdefault('guard', 1)
                token.setdefault('dominion', [])
    triggers = collections.defaultdict(list)
    for block in blocks:
        triggers[block['trigger']].extend(block.get('effects', []))
    package = dict(type=card['type'], keywords=sorted(k.upper() for k in card.get('keywords') or []), effects=dict(triggers))
    return json.dumps(normalize(package), sort_keys=True, separators=(',', ':'))


def audit():
    sets = [json.loads((ROOT / f'data/cards/{f}').read_text(encoding='utf-8'))['cards']
            for f in ('set01_full.json', 'set02.json')]
    groups = collections.defaultdict(list)
    for c in sets[0] + sets[1]:
        if c['type'] != 'WELLSPRING':
            groups[signature(c)].append(c['id'])
    cross, internal = [], []
    for ids in groups.values():
        new = [i for i in ids if i.startswith('SF002-')]
        old = [i for i in ids if i.startswith('SF001-')]
        if new and old:
            cross.append(dict(set01=old, set02=new))
        if len(new) > 1:
            internal.append(new)
    # Also check across sets without treating fast/slow card type as a
    # difference: changing a Ritual into a Rite cannot hide an old effect.
    broad = collections.defaultdict(list)
    for c in sets[0] + sets[1]:
        if c['type'] == 'WELLSPRING':
            continue
        package = json.loads(signature(c))
        package.pop('type')
        broad[json.dumps(package, sort_keys=True)].append(c['id'])
    speed_reprints = []
    for ids in broad.values():
        old = [i for i in ids if i.startswith('SF001-')]
        new = [i for i in ids if i.startswith('SF002-')]
        if old and new:
            speed_reprints.append(dict(set01=old, set02=new))
    return dict(set02NonResources=sum(c['type'] != 'WELLSPRING' for c in sets[1]),
                crossSetDuplicates=cross, set02InternalDuplicates=internal,
                crossSetIgnoringCardTypeDuplicates=speed_reprints,
                resourceException='Basic Wellsprings share the established Aether ability.',
                comparison='Full ordered ability package, normalized defaults and colors; ignores costs, unit stats and presentation.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = audit()
    encoded = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding='utf-8')
    print(encoded)
    raise SystemExit(bool(result['crossSetDuplicates'] or result['set02InternalDuplicates'] or result['crossSetIgnoringCardTypeDuplicates']))
