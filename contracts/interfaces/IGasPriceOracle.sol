pragma solidity ^0.7.0;

interface IGasPriceOracle {
    function latestAnswer() external view returns (int256);

    function latestTimestamp() external view returns (uint256);

    function latestRound() external view returns (uint256);

    function getAnswer(uint256 roundId) external view returns (int256);

    function getTimestamp(uint256 roundId) external view returns (uint256);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        );

    event AnswerUpdated(
        int256 indexed current,
        uint256 indexed roundId,
        uint256 timestamp
    );
    event NewRound(uint256 indexed roundId, address indexed startedBy);
}
