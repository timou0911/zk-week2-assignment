pragma circom 2.1.9;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/mux1.circom";

template CheckRoot(n) { // compute the root of a MerkleTree of n Levels
    var leavesNum = 2 ** n;
    var leafHashNum = leavesNum / 2;
    var parentHashNum = leafHashNum - 1;
    var hashNum = leavesNum - 1;
 
    signal input leaves[leavesNum];
    signal output root;

    //[assignment] insert your code here to calculate the Merkle root from 2^n leaves
    
    component hashes[hashNum];
    
    for (var i = 0; i < n; ++i) {
	    hashes[i] = Poseidon(2);
    }

    for (var i = 0; i < leafHashNum; ++i) {
        hashes[i].inputs[0] <== leaves[i*2];
        hashes[i].inputs[1] <== leaves[i*2+1];
    }

    var j = 0;
    for (var i = leafHashNum; i < hashNum; ++i) {
        hashes[i].inputs[0] <== hashes[k*2].out;
        hashes[i].inputs[1] <== hashes[k*2+1].out;
        ++k;
    }

    root <== hashes[hashNum-1].out;
}

template MerkleTreeInclusionProof(n) {
    signal input leaf;
    signal input path_elements[n];
    signal input path_index[n]; // path index are 0's and 1's indicating whether the current element is on the left or right
    signal output root; // note that this is an OUTPUT signal

    //[assignment] insert your code here to compute the root from a leaf and elements along the path

    signal hashes[n+1];
    hashes[0] <== leaf;
    component poseidons[n];
    component muxs[n];
    
    for (var i = 0; i < n; ++i) {
        path_index[i] * (1 - path_index[i]) === 0;

        poseidons[i] = Poseidon(2);
        muxs[i] = MultiMux1(2);

        muxs[i].c[0][0] <== hashes[i];
        muxs[i].c[0][1] <== path_elements[i];
        muxs[i].c[1][0] <== path_elements[i];
        muxs[i].c[1][1] <== hashes[i];

        muxs[i].s <== path_index[i];

        poseidons[i].inputs[0] <== muxs[i].out[0];
        poseidons[i].inputs[1] <== muxs[i].out[1];

        hashes[i+1] <== poseidons[i].out;
    }

    root <== hashes[n];
}
