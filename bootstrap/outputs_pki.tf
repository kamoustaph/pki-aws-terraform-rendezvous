# ---------------------------------------------------------
# Adresses à renseigner dans EJBCA (profils de certificats)
# ---------------------------------------------------------
#
# terraform output pki_publication

output "pki_publication" {
  description = "Adresses HTTP de publication de la PKI, a renseigner dans EJBCA (CDP et AIA)."
  value = {
    bucket = aws_s3_bucket.pki.bucket

    # Inscrites dans les certificats émis PAR la Root CA (donc dans l'Intermediate).
    root_crl_cdp  = "${local.pki_base_url}/crl/root-ca.crl"
    root_cert_aia = "${local.pki_base_url}/ca/root-ca.crt"

    # Inscrites dans les certificats émis PAR l'Intermediate CA (le certificat de l'ALB).
    intermediate_crl_cdp  = "${local.pki_base_url}/crl/intermediate-ca.crl"
    intermediate_cert_aia = "${local.pki_base_url}/ca/intermediate-ca.crt"
  }
}
