// SPDX-License-Identifier: MIT

// todo: write tests

pragma solidity ^0.8.7;

contract AuctionFactory {
    address public owner;
    uint immutable public fee;
    uint public ownerPrize;

    struct Auction {
        address owner;
        address winner;
        uint highestBid;
        uint endTime;
        mapping(address => uint) buyers;
        bool isWithdrew;
    }

    Auction[] public auctions;

    event AuctionCreated(uint _auctionId);
    event Claimed(uint _auctionId, address _to, uint _amount);
    event NewBid(uint _auctionId, address _bidder, uint _bid);

    constructor(uint _fee) {
        owner = msg.sender;
        fee = _fee;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "you aren't an owner of contract!");
        _;
    }

    // function describes creating a new auction
    function createAuction(uint _duration, uint _startingPrice) external {
        uint id = auctions.length;
        auctions.push();
        Auction storage newAuction = auctions[id];
        newAuction.owner = msg.sender;
        newAuction.highestBid = _startingPrice;
        newAuction.endTime = block.timestamp + _duration;
        newAuction.isWithdrew = false;
        emit AuctionCreated(id);
    }

    // function describes member's bids
    function bid(uint _auctionId) external payable {
        require(_auctionId <= auctions.length - 1, "wrong auction id");
        require(auctions[_auctionId].endTime > block.timestamp, "auction ended");
        require(auctions[_auctionId].highestBid < msg.value, "low bid");
        auctions[_auctionId].highestBid = msg.value;
        auctions[_auctionId].buyers[msg.sender] += msg.value;
        auctions[_auctionId].winner = msg.sender;
        emit NewBid(_auctionId, msg.sender, msg.value);
    }

    // function describes member's claims
    function claim(uint _auctionId) public {
        require(_auctionId <= auctions.length - 1, "wrong auction id");
        require(auctions[_auctionId].buyers[msg.sender] != 0, "you aren't buyer");
        if(msg.sender == auctions[_auctionId].winner) {
            require(auctions[_auctionId].buyers[msg.sender] - auctions[_auctionId].highestBid > 0, "nothing to claim");
            uint amount = auctions[_auctionId].buyers[msg.sender] - auctions[_auctionId].highestBid;
            auctions[_auctionId].buyers[msg.sender] = auctions[_auctionId].highestBid;
            payable(msg.sender).transfer(amount);
            emit Claimed(_auctionId, msg.sender, amount);
        } else {
            uint amount = auctions[_auctionId].buyers[msg.sender];
            auctions[_auctionId].buyers[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
            emit Claimed(_auctionId, msg.sender, amount);
        }
    }
    
    // function describes withdrawal funds by creator after the end of auction
    function withdrawAll(uint _auctionId) external {
        require(_auctionId <= auctions.length - 1, "wrong auction id");
        require(block.timestamp > auctions[_auctionId].endTime, "auction is still ongoing");
        require(msg.sender == auctions[_auctionId].owner, "you aren't an owner");
        require(auctions[_auctionId].highestBid > 0, "nobody set a bid");
        require(!auctions[_auctionId].isWithdrew, "you've already withdrew");
        auctions[_auctionId].isWithdrew = true;
        uint amount = auctions[_auctionId].highestBid - ((auctions[_auctionId].highestBid * fee) / 100);
        ownerPrize = auctions[_auctionId].highestBid - amount;
        (bool success, ) = payable(auctions[_auctionId].owner).call{value: amount}("");
        require(success, "error transfering fee");
    }

    // function describes withdrawal owner's prize
    function withdrawOwnerFee() external onlyOwner {
        require(ownerPrize > 0, "nothing to claim");
        uint amount = ownerPrize;
        ownerPrize = 0;
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "error transfering fee");
    }

    // function describes contract balance
    function balanceOfContract() public view returns(uint) {
        return address(this).balance;
    }

}