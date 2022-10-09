set -o allexport; source ./.env; set +o allexport;
export $(grep -v '^#' .env | xargs -d '\n')

if [[ -z "${ETH_GOERLI_BLOCK}" ]]; then
  anvil -f $ETH_GOERLI_PROVIDER  --chain-id 1337
else
   anvil -f $ETH_GOERLI_PROVIDER --fork-block-number $ETH_GOERLI_BLOCK --chain-id 1337
fi

