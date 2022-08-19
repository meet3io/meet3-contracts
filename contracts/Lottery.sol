// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Lottery is VRFConsumerBaseV2 {
    event LotteryRequested(
        uint256 indexed lotteryId,
        uint256 indexed requestId,
        bytes32 merkleRoot,
        uint32 participantsNum,
        uint32 winnersNum,
        uint64 nonce
    );

    struct LotteryRequestCommitment {
        uint256 blockNum;
        uint256 requestId;
        bytes32 merkleRoot;
        uint32 participantsNum;
        uint32 winnersNum;
        uint64 nonce;
    }

    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // Rinkeby coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    //address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    //Polygon (Matic) Mumbai Testnet
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    //bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    //Polygon (Matic) Mumbai Testnet
    bytes32 keyHash =
        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 2500000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    //uint32 numWords = 2;

    uint64 currentNonce = 1;

    address s_owner;

    mapping(uint256 => LotteryRequestCommitment) /* lotteryId */ /* LotteryRequestCommitment */
        public lotteryRequests;

    mapping(uint256 => uint256[]) /* requestId */ /* randomWords */
        public lotteryRandomWords;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    // Assumes the subscription is funded sufficiently.
    function lottery(
        bytes32 merkleRoot,
        uint32 participantsNum,
        uint32 winnersNum
    ) external onlyOwner returns (uint256) {
        // Will revert if subscription is not set and funded.
        require(winnersNum > 0, "number of winners must greater than 0");
        require(winnersNum <= 500, "number of winners must less than 500");
        require(
            winnersNum < participantsNum,
            "winners must less than participants"
        );

        //chainlink random words
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            winnersNum
        );

        //update nonce
        uint64 nonce = currentNonce + 1;

        //generate lottery id
        uint256 lotteryId = computeLotterytId(
            block.number,
            merkleRoot,
            participantsNum,
            winnersNum,
            requestId,
            nonce
        );

        //save request
        lotteryRequests[lotteryId] = LotteryRequestCommitment({
            blockNum: block.number,
            requestId: requestId,
            merkleRoot: merkleRoot,
            participantsNum: participantsNum,
            winnersNum: winnersNum,
            nonce: nonce
        });

        //save nonce
        currentNonce = nonce;

        emit LotteryRequested(
            lotteryId,
            requestId,
            merkleRoot,
            participantsNum,
            winnersNum,
            nonce
        );
        return lotteryId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        lotteryRandomWords[requestId] = randomWords;
    }

    function winners(uint256 lotteryId) public view returns (uint32[] memory) {
        require(
            lotteryRequests[lotteryId].requestId > 0,
            "lottery id is invalid"
        );

        uint256[] memory randomWords = lotteryRandomWords[
            lotteryRequests[lotteryId].requestId
        ];

        require(randomWords.length > 0, "please wait,lottery is in processing");

        uint32 participantsNum = lotteryRequests[lotteryId].participantsNum;
        uint32 winnersNum = lotteryRequests[lotteryId].winnersNum;

        require(randomWords.length == winnersNum, "random words error");

        // your array which is going to store the shuffled / random numbers
        uint32[] memory randomNumberCache = new uint32[](participantsNum);
        uint32[] memory winnerNumbers = new uint32[](winnersNum);
        // fill our array with numbers from 1 to the maximum value required
        for (uint32 i = 1; i <= participantsNum; i++) {
            randomNumberCache[i - 1] = i;
        }

        for (uint32 i = 0; i < winnersNum; i++) {
            uint256 arraySize = randomNumberCache.length - i;
            // get the random number, divide it by our array size and store the mod of that division.
            // this is to make sure the generated random number fits into our required range
            uint256 randomIndex = (randomWords[i] % (arraySize));

            // draw the current random number by taking the value at the random index
            uint32 resultNumber = randomNumberCache[randomIndex];

            // write the last number of the array to the current position.
            // thus we take out the used number from the circulation and store the last number of the array for future use
            randomNumberCache[randomIndex] = randomNumberCache[arraySize - 1];

            // using the resultNumber as unique random number
            winnerNumbers[i] = resultNumber;
        }

        return winnerNumbers;
    }

    function checkWinner(uint256 lotteryId, uint32 number)
        public
        view
        returns (bool)
    {
        require(
            lotteryRequests[lotteryId].requestId > 0,
            "lottery id is invalid"
        );

        uint256[] memory randomWords = lotteryRandomWords[
            lotteryRequests[lotteryId].requestId
        ];

        require(randomWords.length > 0, "please wait,lottery is in processing");

        uint32 participantsNum = lotteryRequests[lotteryId].participantsNum;
        uint32 winnersNum = lotteryRequests[lotteryId].winnersNum;

        require(randomWords.length == winnersNum, "random words error");

        // your array which is going to store the shuffled / random numbers
        uint32[] memory randomNumberCache = new uint32[](participantsNum);
        // fill our array with numbers from 1 to the maximum value required
        for (uint32 i = 1; i <= participantsNum; i++) {
            randomNumberCache[i - 1] = i;
        }

        for (uint32 i = 0; i < winnersNum; i++) {
            uint256 arraySize = randomNumberCache.length - i;
            // get the random number, divide it by our array size and store the mod of that division.
            // this is to make sure the generated random number fits into our required range
            uint256 randomIndex = (randomWords[i] % (arraySize));

            // draw the current random number by taking the value at the random index
            uint32 resultNumber = randomNumberCache[randomIndex];

            if (number == resultNumber) {
                return true;
            }

            // write the last number of the array to the current position.
            randomNumberCache[randomIndex] = randomNumberCache[arraySize - 1];
        }

        return false;
    }

    function computeLotterytId(
        uint256 blockNum,
        bytes32 merkleRoot,
        uint32 participantsNum,
        uint32 winnersNum,
        uint256 requestId,
        uint64 nonce
    ) private pure returns (uint256) {
        uint256 lotteryId = uint256(
            keccak256(
                abi.encode(
                    blockNum,
                    merkleRoot,
                    participantsNum,
                    winnersNum,
                    requestId,
                    nonce
                )
            )
        );
        return lotteryId;
    }

    modifier onlyOwner() {
        require(msg.sender == s_owner);
        _;
    }
}
