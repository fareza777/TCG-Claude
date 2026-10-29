import unittest
import hashlib
import json
from ability_audit import signature, audit, ROOT


def card(card_id, effects=None, **kwargs):
    return dict(id=card_id, type='UNIT', name=card_id, effects=effects,
                keywords=[], **kwargs)


class AbilityAuditTests(unittest.TestCase):
    def test_names_art_stats_costs_and_color_do_not_hide_reprints(self):
        a = card('SF001-001', [{'trigger': 'ON_ENTER_ARENA', 'effects': [
            {'op': 'GAIN_AETHER', 'amount': 1, 'dominion': 'PYRE'}]}],
            might=2, guard=2, cost={'PYRE': 2}, art_prompt='old')
        b = card('SF002-001', [{'trigger': 'ON_ENTER_ARENA', 'effects': [
            {'op': 'GAIN_AETHER', 'amount': 1, 'dominion': 'TIDE'}]}],
            might=7, guard=8, cost={'TIDE': 6}, art_prompt='new')
        self.assertEqual(signature(a), signature(b))

    def test_implicit_defaults_and_printed_target(self):
        a = card('SF001-002', [{'trigger': 'ON_ENTER_ARENA', 'effects': [
            {'op': 'ADD_COUNTER', 'amount': 1, 'counter': 'PLUS1',
             'target': {'select': 'CHOOSE'}}]}], text='Put a counter on target friendly unit.')
        b = card('SF002-002', [{'trigger': 'ON_ENTER_ARENA', 'effects': [
            {'op': 'ADD_COUNTER', 'amount': 1, 'target': {
                'select': 'CHOOSE', 'owner': 'SELF', 'filter': {'type': 'UNIT'}}}]}])
        self.assertEqual(signature(a), signature(b))
        b['effects'][0]['effects'][0]['target']['owner'] = 'OPPONENT'
        self.assertNotEqual(signature(a), signature(b))

    def test_empty_defaults_and_timing(self):
        self.assertEqual(signature(card('a')), signature(card('b', [])))
        a = card('a', [{'trigger': 'ON_DEATH', 'effects': [{'op': 'DRAW', 'amount': 1}]}])
        b = card('b', [{'trigger': 'ON_VOW', 'effects': [{'op': 'DRAW', 'amount': 1}]}])
        self.assertNotEqual(signature(a), signature(b))

    def test_equivalent_trigger_grouping_and_operation_defaults(self):
        effect = {'op': 'GAIN_AETHER', 'dominion': 'PYRE'}
        a = card('a', [{'trigger': 'ON_ENTER_ARENA', 'effects': [effect]},
                       {'trigger': 'ON_ENTER_ARENA', 'effects': [{'op': 'DRAW', 'amount': 1}]}])
        b = card('b', [{'trigger': 'ON_ENTER_ARENA', 'effects': [
            dict(effect, amount=1), {'op': 'DRAW', 'amount': 1}]}])
        self.assertEqual(signature(a), signature(b))
        b['effects'][0]['effects'].reverse()
        self.assertNotEqual(signature(a), signature(b))

    def test_printed_zone_vocabulary_and_packaged_copies(self):
        for source, packaged in [('set01_full.json', 'set01.json'), ('set02.json', 'set02.json')]:
            raw = (ROOT / 'data/cards' / source).read_bytes()
            self.assertEqual(raw, (ROOT / 'app/assets/data' / packaged).read_bytes())
            doc = json.loads(raw)
            for c in doc['cards']:
                text = c.get('text', '').lower()
                self.assertNotIn('arena', text, c['id'])
                for block in c.get('effects') or []:
                    if block['trigger'] == 'ON_ENTER_ARENA':
                        self.assertIn('enters play', text, c['id'])
                    if block['trigger'] == 'ON_VOW':
                        self.assertIn('still in play', text, c['id'])

    def test_original_set_gameplay_is_unchanged(self):
        doc = json.loads((ROOT / 'data/cards/set01_full.json').read_text(encoding='utf-8'))
        presentation = {'text','flavor','art_prompt','art_intent','art_composition','art_narrative'}
        payload = [{k:v for k,v in c.items() if k not in presentation} for c in doc['cards']]
        digest = hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(digest, 'f9b6cc67c3f8c409f1d86d37feb8e3235f32e5ece7b1dd1d7382575d97020c97')

    def test_real_catalog_has_no_expansion_reprints_or_internal_twins(self):
        result = audit()
        self.assertEqual(result['crossSetDuplicates'], [])
        self.assertEqual(result['crossSetIgnoringCardTypeDuplicates'], [])
        self.assertEqual(result['set02InternalDuplicates'], [])
        self.assertEqual(result['set02NonResources'], 210)


if __name__ == '__main__':
    unittest.main()
