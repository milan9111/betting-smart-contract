// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

contract Betting {
    address payable public owner;
    uint256 public minimumBet = 100000000000000; //0,0001 ETH
    uint256 public maxBet = 10000000000000000; // 0,01 ETH
    address payable[] public creators;
    mapping(address => uint256) public failedPrizes;

    struct Player {
        uint256 amountBet;
        uint16 teamSelected;
    }

    struct Match {
        uint256 totalBetOne;
        uint256 totalBetTwo;
        uint256 totalBetDraw;
        uint256 numberOfBets;
        uint256 coefficientOne;
        uint256 coefficientTwo;
        uint256 coefficientDraw;
        uint256 startMatch;
        uint256 endMatch;
        address payable[] players;
        mapping(address => Player) playerInfo;
        address payable[] winners;
        bool finished;
    }

    Match[] public matches;

    event MatchCreated(uint256 indexed index);
    event DistributedPrizes(
        bool indexed finished,
        address payable[] indexed arrayWinners
    );

    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    constructor() {
        owner = payable(msg.sender);
    }

    function getBalance() public view isOwner returns (uint256) {
        return address(this).balance;
    }

    function putStorageBetting() public payable isOwner {
        uint256 b = address(this).balance;
        b += msg.value;
    }

    function transferStorageBetting() public isOwner {
        owner.transfer(address(this).balance);
    }

    receive() external payable {}

    function createMatch(
        uint256 _coefficientOne,
        uint256 _coefficientTwo,
        uint256 _coefficientDraw,
        uint256 _startMatch,
        uint256 _endMatch
    ) external {
        require(_startMatch > block.timestamp, "The match has already started");
        Match storage newMatch = matches.push();
        newMatch.coefficientOne = _coefficientOne;
        newMatch.coefficientTwo = _coefficientTwo;
        newMatch.coefficientDraw = _coefficientDraw;
        newMatch.startMatch = _startMatch;
        newMatch.endMatch = _endMatch;
        newMatch.finished = false;
        emit MatchCreated(matches.length - 1);
        creators.push(payable(msg.sender));
    }

    function checkPlayerExists(uint256 index, address player)
        public
        view
        returns (uint256)
    {
        Match storage currMatch = matches[index];
        return currMatch.playerInfo[player].amountBet;
    }

    function makeBet(uint256 index, uint8 _teamSelected) public payable {
        require(msg.sender.code.length == 0, "No contracts!");
        Match storage currMatch = matches[index];

        require(
            checkPlayerExists(index, msg.sender) == 0,
            "This player already has made a bet"
        );
        require(
            msg.value >= minimumBet,
            "A bet must be bigger than 0.0001 ETH"
        );
        require(msg.value <= maxBet, "A bet must be less than 0.01 ETH");
        require(currMatch.finished == false, "The match has already finished");
        require(
            currMatch.startMatch > block.timestamp,
            "The match has already started"
        );

        currMatch.playerInfo[msg.sender].amountBet = msg.value;
        currMatch.playerInfo[msg.sender].teamSelected = _teamSelected;
        currMatch.players.push(payable(msg.sender));

        if (_teamSelected == 1) {
            currMatch.totalBetOne += msg.value;
        } else if (_teamSelected == 2) {
            currMatch.totalBetTwo += msg.value;
        } else {
            currMatch.totalBetDraw += msg.value;
        }
        currMatch.numberOfBets++;
    }

    function distributePrizes(uint256 index, uint256 teamWinner) external {
        require(msg.sender.code.length == 0, "No contracts!");
        Match storage currMatch = matches[index];
        require(
            currMatch.endMatch < block.timestamp,
            "The match has not finished yet"
        );
        require(
            currMatch.finished == false,
            "Prizes have already been distributed!"
        );
        uint256 count = 0;
        uint256 winnerCoefficient = 0;
        address add;
        uint256 bet;
        uint256 sumWin;
        uint256 creatorBonus;
        address payable playerAddress;

        for (uint256 i = 0; i < currMatch.players.length; i++) {
            playerAddress = currMatch.players[i];
            if (
                currMatch.playerInfo[playerAddress].teamSelected == teamWinner
            ) {
                currMatch.winners.push(playerAddress);
                count++;
            }
        }

        if (teamWinner == 1) {
            winnerCoefficient = currMatch.coefficientOne;
        } else if (teamWinner == 2) {
            winnerCoefficient = currMatch.coefficientTwo;
        } else if (teamWinner == 3) {
            winnerCoefficient = currMatch.coefficientDraw;
        }

        for (uint256 j = 0; j < count; j++) {
            if (currMatch.winners[j] != address(0)) {
                add = currMatch.winners[j];
                bet = currMatch.playerInfo[add].amountBet;
                sumWin = (bet * winnerCoefficient) / 100;
                if (address(this).balance <= sumWin) {
                    failedPrizes[currMatch.winners[j]] = sumWin;
                } else {
                    address(this).balance - sumWin;
                    currMatch.winners[j].transfer(sumWin);
                    sumWin = 0;
                }
            }
        }

        if (
            currMatch.totalBetOne +
                currMatch.totalBetTwo +
                currMatch.totalBetDraw !=
            0
        ) {
            creatorBonus =
                ((currMatch.totalBetOne +
                    currMatch.totalBetTwo +
                    currMatch.totalBetDraw) / 100) *
                5;
        } else {
            creatorBonus = 0;
        }
        address(this).balance - creatorBonus;
        creators[index].transfer(creatorBonus);

        currMatch.finished = true;
        emit DistributedPrizes(true, currMatch.winners);
    }

    function AmountOne(uint256 index) external view returns (uint256) {
        Match storage currMatch = matches[index];
        return currMatch.totalBetOne;
    }

    function AmountTwo(uint256 index) external view returns (uint256) {
        Match storage currMatch = matches[index];
        return currMatch.totalBetTwo;
    }

    function AmountDraw(uint256 index) external view returns (uint256) {
        Match storage currMatch = matches[index];
        return currMatch.totalBetDraw;
    }
}
