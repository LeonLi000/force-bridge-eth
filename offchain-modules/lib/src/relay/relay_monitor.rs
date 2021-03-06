use crate::util::ckb_tx_generator::Generator;
use crate::util::ckb_util::{parse_cell, parse_merkle_cell_data};
use crate::util::eth_util::{convert_eth_address, Web3Client};
use anyhow::{anyhow, Result};
use force_sdk::cell_collector::get_live_cell_by_typescript;
use std::ops::Sub;

#[allow(clippy::too_many_arguments)]
pub async fn relay_monitor(
    ckb_rpc_url: String,
    ckb_indexer_url: String,
    eth_rpc_url: String,
    eth_ckb_chain_addr: String,
    cell: String,
    ckb_alarm_number: u64,
    eth_alarm_number: u64,
    alarm_url: String,
    ckb_conservator: Vec<String>,
    eth_conservator: Vec<String>,
) -> Result<()> {
    let contract_addr = convert_eth_address(&eth_ckb_chain_addr)?;
    let mut web3_client = Web3Client::new(eth_rpc_url);
    let mut generator = Generator::new(ckb_rpc_url, ckb_indexer_url, Default::default())
        .map_err(|e| anyhow!("failed to crate generator: {}", e))?;
    let ckb_light_client_height = web3_client
        .get_contract_height("latestBlockNumber", contract_addr)
        .await?;
    let ckb_current_height = generator
        .rpc_client
        .get_tip_block_number()
        .map_err(|e| anyhow!("failed to get ckb current height : {}", e))?;

    let eth_current_height = web3_client.client().eth().block_number().await?;

    let script = parse_cell(&cell).map_err(|e| anyhow!("get typescript fail {:?}", e))?;

    let cell = get_live_cell_by_typescript(&mut generator.indexer_client, script)
        .map_err(|e| anyhow!("get live cell fail: {}", e))?
        .ok_or_else(|| anyhow!("eth header cell not exist"))?;

    let (_, eth_light_client_height, _) =
        parse_merkle_cell_data(cell.output_data.as_bytes().to_vec())
            .map_err(|e| anyhow!("parse header data fail: {}", e))?;
    let ckb_diff = ckb_current_height - ckb_light_client_height;
    let eth_diff = eth_current_height.sub(eth_light_client_height).as_u64();

    let mut msg = format!("ckb light client height : {:?}  %0A ckb current height : {:?}  %0A eth light client height : {:?}  %0A eth current height : {:?} %0A ckb height difference is {:?}, eth height difference is {:?} %0A ",ckb_light_client_height,ckb_current_height,eth_light_client_height,eth_current_height,ckb_diff,eth_diff);

    if ckb_alarm_number < ckb_diff {
        for conservator in ckb_conservator.iter() {
            msg = format!("{} @{} ", msg, conservator,);
        }
        msg = format!("{} %0A ", msg);
    }

    if eth_alarm_number < eth_diff {
        for conservator in eth_conservator.iter() {
            msg = format!("{} @{} ", msg, conservator,);
        }
        msg = format!("{} %0A ", msg);
    }

    let res = reqwest::get(format!("{}{}", alarm_url, msg).as_str())
        .await?
        .text()
        .await?;
    log::info!("{:?}", res);
    Ok(())
}
