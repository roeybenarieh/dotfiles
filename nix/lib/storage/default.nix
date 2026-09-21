{ lib, ... }:

rec {
  ## Garage (the s3compatible storage backend) requires S3 access key IDs in the
  ## strict format `GK` + 24 hex chars, so the real credential is derived
  ## deterministically from the human-chosen accessKey.
  ##
  #@ String -> String
  s3compatible_key_id = accessKey: "GK" + lib.substring 0 24 (builtins.hashString "sha256" accessKey);

  ## Garage requires S3 secret access keys to be 32 hex-encoded bytes, so the
  ## real credential is derived deterministically from the human-chosen secretKey.
  ##
  #@ String -> String
  s3compatible_key_secret = secretKey: builtins.hashString "sha256" secretKey;
}
