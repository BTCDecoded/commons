//! BLLVM - Bitcoin Low-Level Virtual Machine Node
//!
//! Main entry point for the Bitcoin Commons BLLVM node binary.
//! This binary starts a full Bitcoin node using the bllvm-node library.

use anyhow::Result;
use bllvm_node::node::Node as ReferenceNode;
use bllvm_node::ProtocolVersion;
use clap::{Parser, ValueEnum};
use std::net::SocketAddr;
use tokio::signal;
use tracing::{error, info, warn};

#[derive(Parser)]
#[command(name = "bllvm")]
#[command(about = "Bitcoin Commons BLLVM - Bitcoin Low-Level Virtual Machine Node", long_about = None)]
struct Cli {
    /// Network to connect to
    #[arg(short, long, value_enum, default_value = "regtest")]
    network: Network,

    /// RPC server address
    #[arg(short, long, default_value = "127.0.0.1:18332")]
    rpc_addr: SocketAddr,

    /// P2P listen address
    #[arg(short, long, default_value = "0.0.0.0:8333")]
    listen_addr: SocketAddr,

    /// Data directory
    #[arg(short, long, default_value = "./data")]
    data_dir: String,

    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,
}

#[derive(Clone, ValueEnum)]
enum Network {
    /// Regression testing network (default, safe for development)
    Regtest,
    /// Bitcoin test network
    Testnet,
    /// Bitcoin mainnet (use with caution)
    Mainnet,
}

impl From<Network> for ProtocolVersion {
    fn from(network: Network) -> Self {
        match network {
            Network::Regtest => ProtocolVersion::Regtest,
            Network::Testnet => ProtocolVersion::Testnet3,
            Network::Mainnet => ProtocolVersion::BitcoinV1,
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize tracing
    let filter = if cli.verbose {
        "bllvm=debug,bllvm_node=debug"
    } else {
        "bllvm=info,bllvm_node=info"
    };

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(filter)),
        )
        .init();

    info!("Starting Bitcoin Commons BLLVM Node");
    info!("Network: {:?}", cli.network);
    info!("RPC address: {}", cli.rpc_addr);
    info!("P2P listen address: {}", cli.listen_addr);
    info!("Data directory: {}", cli.data_dir);

    // Set data directory environment variable
    std::env::set_var("DATA_DIR", &cli.data_dir);

    // Create node with specified protocol version
    let protocol_version: ProtocolVersion = cli.network.clone().into();
    let mut node = match ReferenceNode::new(
        &cli.data_dir,
        cli.listen_addr,
        cli.rpc_addr,
        Some(protocol_version),
    ) {
        Ok(node) => node,
        Err(e) => {
            error!("Failed to create node: {}", e);
            return Err(e);
        }
    };

    // Start node in background task
    let node_handle = tokio::spawn(async move {
        if let Err(e) = node.start().await {
            error!("Node error: {}", e);
            std::process::exit(1);
        }
    });

    // Wait for shutdown signal (Ctrl+C or SIGTERM)
    match signal::ctrl_c().await {
        Ok(()) => {
            info!("Shutting down BLLVM node...");
            node_handle.abort();
            info!("Node stopped");
        }
        Err(err) => {
            error!("Unable to listen for shutdown signal: {}", err);
            node_handle.abort();
            return Err(err.into());
        }
    }

    Ok(())
}

