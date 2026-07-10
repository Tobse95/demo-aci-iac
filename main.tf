# Self-service variable files land in subnets/<name>.yaml
# This module reads them all and creates the corresponding ACI resources.
#
# In production, replace null_resource with:
#   - resource "aci_bridge_domain"
#   - resource "aci_subnet"
#   - resource "aci_application_epg"
#   - resource "aci_epg_to_domain"

locals {
  subnets = {
    for f in fileset("${path.module}/subnets", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/subnets/${f}"))
  }
}

# Represents aci_bridge_domain + aci_subnet
resource "null_resource" "bridge_domain" {
  for_each = local.subnets

  triggers = {
    bd_name = "BD_${upper(each.key)}"
    cidr    = each.value.cidr
    gateway = each.value.gateway
    vlan_id = tostring(each.value.vlan_id)
    tenant  = each.value.tenant
    vrf     = each.value.vrf
  }
}

# Represents aci_application_epg + aci_epg_to_domain
resource "null_resource" "epg" {
  for_each = local.subnets

  triggers = {
    epg_name = "EPG_${upper(each.key)}"
    bd_name  = "BD_${upper(each.key)}"
    ap       = each.value.ap
    domain   = each.value.domain
  }

  depends_on = [null_resource.bridge_domain]
}

output "provisioned_subnets" {
  description = "Summary of subnets managed by this workspace"
  value = {
    for k, v in local.subnets : k => {
      bd_name  = "BD_${upper(k)}"
      epg_name = "EPG_${upper(k)}"
      cidr     = v.cidr
      vlan_id  = v.vlan_id
      tenant   = v.tenant
    }
  }
}
