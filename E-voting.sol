// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract ElectionContract {
    // Define entities
    struct Participant {
        address id;
    bool verified;
    bool approved;
    uint approvalsCount;
    bool passedToNext;
    address nextParticipant;
    }

    struct Candidate {
        uint id;
        string name;
        uint voteCount;
    }

    struct Voter {
        address id;
        bool voted;
        uint candidateIndex;
        uint randV;
        bool approved;
    }

    // Define roles
    address public electionAdmin;
    mapping(address => Participant) public participants;
    mapping(address => bool) public authorities;
    mapping(uint => Candidate) public candidates;
    mapping(address => Voter) public voters;
    uint public numCandidates;
    address[] public authoritiesList;
    uint public threshold; // Number of approvals required

    // Define states
    enum ElectionState { NotStarted, PreElection, Election, PostElection }
    ElectionState public state;

    // Events
    event ParticipantVerified(address participant);
    event ElectionStarted();
    event ElectionEnded();
    event RequestPassed(address fromParticipant, address toParticipant);
    event ParticipantApproved(address participant);

    modifier onlyAdmin() {
        require(msg.sender == electionAdmin, "Only admin can perform this operation");
        _;
    }

    constructor(uint _threshold) {
        electionAdmin = msg.sender;
        state = ElectionState.NotStarted;
        threshold = _threshold;
    }

    // ElGamal key parameters
    uint public prime;
    uint public generator;
    uint public privateKey;
    uint public publicKey;

    // Helper function to generate a random number within a range
    function getRandomNumber(uint _range) private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp, block.basefee, _range))) % _range;
    }

    // Helper function to calculate modular exponentiation (base^exponent % modulus)
    function modExp(uint _base, uint _exponent, uint _modulus) private pure returns (uint result) {
        result = 1;
        for (uint i = 0; i < _exponent; i++) {
            result = (result * _base) % _modulus;
        }
    }

    // Generate ElGamal keys
    function generateElGamalKeys() external onlyAdmin {
        // Generate a large prime number (for simplicity, you can set this manually)
        prime = 1000000007;

        // Choose a generator (primitive root modulo prime)
        generator = 2;

        // Generate a random private key
        privateKey = getRandomNumber(prime - 1) + 1;

        // Compute the public key
        publicKey = modExp(generator, privateKey, prime);
    }

    function verifyParticipant(address _participant) external onlyAdmin {
        participants[_participant].verified = true;
        emit ParticipantVerified(_participant);
    }

    function startElection() external onlyAdmin {
        require(state == ElectionState.NotStarted, "Election has already started");
        state = ElectionState.PreElection;
        emit ElectionStarted();
    }

    function addCandidate(string memory _name) external onlyAdmin {
        require(state == ElectionState.PreElection, "Cannot add candidate now");
        numCandidates++;
        candidates[numCandidates] = Candidate(numCandidates, _name, 0);
    }

    function vote(uint _candidateIndex, uint _randV) external {
        require(state == ElectionState.Election, "Voting is not allowed now");
        require(participants[msg.sender].verified, "Participant not verified");
        require(!voters[msg.sender].voted, "Already voted");
        require(voters[msg.sender].approved, "Voter not approved");

        // Encrypt token using ElGamal

        voters[msg.sender] = Voter(msg.sender, true, _candidateIndex, _randV, false);
        candidates[_candidateIndex].voteCount++;
    }

    function endElection() external onlyAdmin {
        require(state == ElectionState.Election, "Election has not started yet");
        state = ElectionState.PostElection;
        emit ElectionEnded();
    }

    function passRequestToNextParticipant(address _nextParticipant) external {
        require(participants[msg.sender].verified, "Participant not verified");
        require(!participants[msg.sender].passedToNext, "Request already passed to next participant");

        participants[msg.sender].nextParticipant = _nextParticipant;
        participants[msg.sender].passedToNext = true;
        emit RequestPassed(msg.sender, _nextParticipant);
    }

    function beginVoting() external onlyAdmin {
        require(state == ElectionState.PreElection, "Voting cannot begin now");
        state = ElectionState.Election;
    }

    function calculateResults() external view onlyAdmin {
        require(state == ElectionState.PostElection, "Election results cannot be calculated yet");

        // Loop through candidates and calculate their total votes
        for (uint i = 1; i <= numCandidates; i++) {
            // Store the vote count for each candidate
            candidates[i].voteCount;
        }
    }

      function getWinner() external view returns (string memory) {
        require(state == ElectionState.PostElection, "Election results not available yet");

        uint winningVoteCount = 0;
        uint winningCandidateId = 0;

        // Loop through candidates to find the one with the highest vote count
        for (uint i = 1; i <= numCandidates; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winningCandidateId = i;
            }
        }

        return candidates[winningCandidateId].name;
    }
}