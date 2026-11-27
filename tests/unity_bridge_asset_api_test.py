import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch, Mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "unity_bridge"))
from probe_asset_manager_api import _org_id_from_data, check_api, discover_org_id

class UnityAssetManagerApiProbeTest(unittest.TestCase):
    def test_explicit_org_keys_only(self):
        self.assertEqual(_org_id_from_data({"data": {"activeOrganizationId": "1234567890123"}}), "1234567890123")
        self.assertEqual(_org_id_from_data({"data": {"activeOrganization": {"genesisId": "1234567890123"}}}), "1234567890123")
        self.assertIsNone(_org_id_from_data({"data": {"projectId": "1234567890123"}}))
        self.assertIsNone(_org_id_from_data({"data": {"organizationId": "invalid/../id"}}))

    def test_mocked_rest_reads_exact_project_and_never_uses_redirect(self):
        response = Mock(status=200)
        response.read.return_value = b'{"projects":[{"name":"Imperathen"}]}'
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        with patch("probe_asset_manager_api.build_opener") as opener:
            opener.return_value.open.return_value = response
            result = check_api("1234567890123", "key", "secret")
        self.assertEqual(result["result"], "IMPERATHEN_VISIBLE")
        request = opener.return_value.open.call_args.args[0]
        self.assertEqual(request.full_url.split("?")[0],
                         "https://services.api.unity.com/assets/v1/organizations/1234567890123/projects")
        self.assertEqual(request.get_method(), "GET")

    def test_empty_projects_are_not_mistaken_for_connected_project(self):
        response = Mock(status=200)
        response.read.return_value = b'{"projects":[]}'
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        with patch("probe_asset_manager_api.build_opener") as opener:
            opener.return_value.open.return_value = response
            result = check_api("1234567890123", "key", "secret")
        self.assertEqual(result["result"], "NO_PROJECTS_VISIBLE")
        self.assertEqual(result["project_count_on_page"], 0)

    def test_rejects_bad_org_before_network(self):
        result = check_api("../", "key", "secret")
        self.assertEqual(result["result"], "ORG_ID_INVALID")
