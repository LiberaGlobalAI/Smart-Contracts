// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LiberaTokenContract is ERC20 {
    constructor() ERC20("LiberaToken", "LIBE") {
        uint256 initialSupply = 5000000000 * 10**decimals();
        _mint(msg.sender, initialSupply);
    }
}

contract LiberaPacketContract is Ownable {
    // This contract is used for packet creation, its functionality, and distributing rewards.

    LiberaTokenContract private token;
    address public rewardPoolWallet;
    uint256 public deployTime;

    struct PacketStruct {
        uint256 id;
        address owner;
        string name;
        string dataHash;
        string dataType;
        uint256 timestamp;
        bool validated;
        uint256 reward;
        uint256 rewarded;
    }

    mapping(uint256 => PacketStruct) private packets;
    mapping(string => uint256) private dataHashToPacketId;
    uint256 private _nextPacketID = 1;

    event PacketAddedEvent(
        address indexed _owner,
        string indexed _dataHash,
        string _dataType
    );
    event PacketValidatedEvent(uint256 _id, bool _isValid);
    event RewardSetEvent(uint256 _id, uint256 _reward);
    event RewardDistributedEvent(uint256 _id, uint256 _reward);

    error onlyRewardPoolError();
    error packetDoesExistError();
    error packetDoesNotExistError();
    error rewardShouldNotBeZeroError();
    error packetIsNotValidError();

    constructor(address _tokenAddress, address _rewardPoolWallet)
        Ownable(msg.sender)
    {
        // This constructor is used to set the TokenContract address and RewardPool wallet address.

        token = LiberaTokenContract(_tokenAddress);
        rewardPoolWallet = _rewardPoolWallet;

        deployTime = block.timestamp;
    }

    modifier onlyRewardPool() {
        if (msg.sender != rewardPoolWallet) revert onlyRewardPoolError();
        _;
    }

    function addPacket(
        address _owner,
        string calldata _name,
        string calldata _dataHash,
        string calldata _dataType
    ) external onlyOwner {
        // This method is used for packet creation by the owner.
        // typically called from the main application with the owner's authorisation.

        if (dataHashToPacketId[_dataHash] != 0) revert packetDoesExistError();

        packets[_nextPacketID] = PacketStruct(
            _nextPacketID,
            _owner,
            _name,
            _dataHash,
            _dataType,
            block.timestamp,
            false,
            0,
            0
        );

        emit PacketAddedEvent(_owner, _dataHash, _dataType);

        dataHashToPacketId[_dataHash] = _nextPacketID;
        _nextPacketID++;
    }

    function getPacketByDataHash(string calldata _dataHash)
        external
        view
        returns (PacketStruct memory)
    {
        // This method is used to retrieve packet data using the packet's data hash.

        uint256 _packetId = dataHashToPacketId[_dataHash];
        if (_packetId == 0) revert packetDoesNotExistError();

        return packets[_packetId];
    }

    function validatePacket(uint256 _id, bool _isValid) external onlyOwner {
        // This method is used to set the validated flag of a packet by the owner, which can be either true or false.

        if (packets[_id].id != _id) revert packetDoesNotExistError();

        packets[_id].validated = _isValid;

        emit PacketValidatedEvent(_id, _isValid);

        if (!_isValid) {
            packets[_id].reward = 0;
        }
    }

    function setReward(uint256 _id, uint256 _reward) external onlyOwner {
        // This method is used to set the reward value of a packet by the owner.

        if (_reward == 0) revert rewardShouldNotBeZeroError();
        if (packets[_id].id != _id) revert packetDoesNotExistError();
        if (packets[_id].validated == false) revert packetIsNotValidError();

        packets[_id].reward = _reward;

        emit RewardSetEvent(_id, _reward);
    }

    function distributeReward(uint256 _id) external onlyRewardPool {
        //  This method is used for distributing the packet's reward to the packet's owner.
        // It may be called multiple times since the packets can be sold multiple times.

        if (packets[_id].validated == false) revert packetIsNotValidError();
        if (packets[_id].reward == 0) revert rewardShouldNotBeZeroError();

        bool successRewardTransfer = token.transferFrom(
            rewardPoolWallet,
            packets[_id].owner,
            packets[_id].reward
        );

        if (successRewardTransfer) {
            packets[_id].rewarded += packets[_id].reward;
            emit RewardDistributedEvent(_id, packets[_id].reward);
        }
    }
}
