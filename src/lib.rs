// Here we're calling a macro exported with Uniffi. This macro will
// write some functions and bind them to FFI type. These
// functions will invoke the `get_circom_wtns_fn` generated below.
mopro_ffi::app!();

use semaphore_rs::{
    get_supported_depths, hash_to_field, identity::Identity, poseidon_tree::LazyPoseidonTree,
    protocol::*, Field,
};

#[derive(uniffi::Record)] // if using proc-macros
struct ProofResult {
    inputs: String,
    proof: String,
}

#[uniffi::export]
fn get_id_commitment(id_secret: String) -> String {
    let mut secret: [u8; 5] = [0; 5]; // Initialize with zeroes
    let bytes = id_secret.as_bytes();
    secret[..bytes.len().min(5)].copy_from_slice(&bytes[..bytes.len().min(5)]);
    let id = Identity::from_secret(&mut secret, None);
    return id.commitment().to_string();
}

#[uniffi::export]
fn semaphore_prove(
    id_secret: String,
    leaves: Vec<String>,
    signal: String,
    external_nullifier: String,
) -> ProofResult {
    // generate identity
    let mut secret: [u8; 5] = [0; 5]; // Initialize with zeroes
    let bytes = id_secret.as_bytes();
    secret[..bytes.len().min(5)].copy_from_slice(&bytes[..bytes.len().min(5)]);
    let id = Identity::from_secret(&mut secret, None);

    // Get the first available tree depth. This is controlled by the crate features.
    let depth = get_supported_depths()[0];

    // generate merkle tree
    let empty_leaf = Field::from(0);
    let mut tree = LazyPoseidonTree::new(depth, empty_leaf).derived();
    let mut user_index = 0;
    for (index, leaf_str) in leaves.iter().enumerate() {
        let field_value = Field::from_str_radix(&leaf_str, 10).expect("Invalid decimal string");
        tree = tree.update(index, &field_value);
        if id.commitment() == field_value {
            user_index = index;
        }
    }
    let merkle_proof = tree.proof(user_index);
    let root = tree.root();

    // change signal and external_nullifier here
    let signal_hash = hash_to_field(signal.as_bytes());
    let external_nullifier_hash = hash_to_field(external_nullifier.as_bytes());

    let nullifier_hash = generate_nullifier_hash(&id, external_nullifier_hash);

    let proof = generate_proof(&id, &merkle_proof, external_nullifier_hash, signal_hash).unwrap();
    let reserialized = serde_json::to_string(&proof).unwrap();
    let serialized_inputs =
        serde_json::to_string(&[root, nullifier_hash, signal_hash, external_nullifier_hash])
            .unwrap();
    let proof_result = ProofResult {
        inputs: serialized_inputs,
        proof: reserialized,
    };
    proof_result
}

#[uniffi::export]
fn semaphore_verify(proof: ProofResult) -> bool {
    let deserialized_inputs: Vec<Field> = serde_json::from_str(&proof.inputs).unwrap();
    let deserialized: Proof = serde_json::from_str(&proof.proof).unwrap();
    let depth = get_supported_depths()[0];
    let success = verify_proof(
        deserialized_inputs[0],
        deserialized_inputs[1],
        deserialized_inputs[2],
        deserialized_inputs[3],
        &deserialized,
        depth,
    )
    .unwrap();
    success
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_semaphore_test() {
        let id_secret = "secret";
        let signal = "xxx";
        let external_nullifier = "appId";
        let leaves = vec![
            "3".to_string(),
            get_id_commitment(id_secret.to_string()),
            "3".to_string(),
            "4".to_string(),
            "5".to_string(),
        ];
        let proof_result = semaphore_prove(
            id_secret.to_string(),
            leaves,
            signal.to_string(),
            external_nullifier.to_string(),
        );
        let success = semaphore_verify(proof_result);
        assert!(success);
    }
}
