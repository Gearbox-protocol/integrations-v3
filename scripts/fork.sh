set -o allexport; source ./.env; set +o allexport;
export $(grep -v '^#' .env | xargs -d '\n')

if [[ -z "${ETH_MAINNET_BLOCK}" ]]; then
  anvil -f $ETH_MAINNET_PROVIDER  --chain-id 1337
else
  anvil -f $ETH_MAINNET_PROVIDER --fork-block-number $ETH_MAINNET_BLOCK --chain-id 1337
fi

