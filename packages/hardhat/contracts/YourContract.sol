pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "hardhat/console.sol";

// import "@openzeppelin/contracts/access/Ownable.sol";
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract YourContract is VRFConsumerBase, ConfirmedOwner(msg.sender) {
    bytes32 private s_keyHash;
    uint256 private s_fee;
    mapping(bytes32 => address) private s_flippers;
    mapping(address => uint256) private s_results;
    uint256 private constant FLIP_IN_PROGRESS = 42;

    AggregatorV3Interface internal priceFeed;

    event CoinFlipped(bytes32 indexed requestId, address indexed flipper);
    event CoinLanded(bytes32 indexed requestId, uint256 indexed result);

    //The contract requires some LINK to function (each flipCoin call spends 0.1 LINK from contract balance)
    /**
     * Network: Kovan
     * Aggregator: ETH/USD
     * Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
     */
    constructor(
        address vrfCoordinator,
        address link,
        bytes32 keyHash
    ) VRFConsumerBase(vrfCoordinator, link) {
        s_keyHash = keyHash;
        s_fee = 0.1 * 10**18; // 0.1 LINK (for Kovan, varies by network)
        priceFeed = AggregatorV3Interface(
            0x9326BFA02ADD2366b30bacB125260Af641031331
        );
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function flipCoin(address flipper)
        public
        onlyOwner
        returns (bytes32 requestId)
    {
        // Checking LINK balance of the contract. This implies that the deployer should top up the contract with LINK
        require(
            LINK.balanceOf(address(flipper)) >= s_fee,
            "Not enough LINK to pay fee"
        );

        // checking if flipper has already flipped the coin
        require(s_results[flipper] == 0, "Already flipped");

        // requesting randomness
        requestId = requestRandomness(s_keyHash, s_fee);

        // storing requestId and flipper address
        s_flippers[requestId] = flipper;

        // emitting event to signal flipping of coin
        s_results[flipper] = FLIP_IN_PROGRESS;
        emit CoinFlipped(requestId, flipper);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        // transform the random result to either 1 or 2
        uint256 d20Value = (randomness % 2) + 1;

        // assign the transformed value to the address in the s_results mapping variable
        s_results[s_flippers[requestId]] = d20Value;

        // emitting event to signal that coin landed
        emit CoinLanded(requestId, d20Value);
    }

    function coinSide(address player) public view returns (string memory) {
        // coin has not yet been flipped to this address
        require(s_results[player] != 0, "Coin not flipped");

        // not waiting for the result of a flipped coin
        require(s_results[player] != FLIP_IN_PROGRESS, "flip in progress");

        // returns the house name from the name list function
        if (s_results[player] > 1) {
            return "Heads";
        } else {
            return "Tails";
        }
    }
}
