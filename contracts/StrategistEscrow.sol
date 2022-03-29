// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract StrategistEscrow {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //constant stays through clone
    IERC20 public constant yfi =
        IERC20(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e);
    uint256 internal constant ONEYEAR = 365 days;
    uint256 internal constant ONEMONTH = ONEYEAR / 12;
    uint256 internal constant FOURYEARS = 4 * ONEYEAR;


    //non constant doesnt. so will be false on all but original
    bool internal isOriginal = true;

    event EscrowSetup(
        address escrowAddress,
        address strategist,
        uint256 releaseTime
    );

    event Swept(address token, uint256 amount, address target);

    address public strategist;
    address public pendingStrategist;
    address public ychad;
    address public pendingYchad;

    address public migrateTargetStrategist;
    address public migrateTargetYchad;

    uint256 public releaseTime;

    constructor(address _strategist, uint256 _releaseTime) public {
        initialize(_strategist, _releaseTime);
    }

    function cloneEscrow(address _strategist, uint256 _releaseTime)
        external
        returns (address newEscrow)
    {
        require(isOriginal);
        // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        bytes20 addressBytes = bytes20(address(this));
        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(
                clone_code,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(
                add(clone_code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            newEscrow := create(0, clone_code, 0x37)
        }

        StrategistEscrow(newEscrow).initialize(_strategist, _releaseTime);
    }

    function initialize(address _strategist, uint256 _releaseTime) public {
        require(releaseTime == 0, "already Initialised");

        //note: strategist needs to accept. Important or else daddy can sweep
        pendingStrategist = _strategist;
        require(
            _releaseTime <= block.timestamp.add(FOURYEARS).add(ONEMONTH),
            "_releaseTime > 4y1"
        );
        require(_releaseTime > block.timestamp, "_releaseTime in past");
        releaseTime = _releaseTime;

        ychad = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;

        emit EscrowSetup(address(this), _strategist, _releaseTime);
    }

    function changePendingStrategist(address _newStrategist) external {
        require(strategist == address(0));
        require(ychad == msg.sender);
        require(_newStrategist != address(0), "cant set to zero");
        pendingStrategist = _newStrategist;
    }

    function changeStrategist(address _newStrategist) external {
        require(strategist == msg.sender);
        require(_newStrategist != address(0), "cant set to zero");
        pendingStrategist = _newStrategist;
    }

    function acceptStrategist() external {
        require(pendingStrategist == msg.sender);
        strategist = pendingStrategist;
    }

    function changeYchad(address _newYchad) external {
        require(ychad == msg.sender);
        pendingYchad = _newYchad;
    }

    function acceptYchad() external {
        require(pendingYchad == msg.sender);
        ychad = pendingYchad;
    }

    //ychad can improve release time. must in future to prevenet gaming of sweepFromDeadStrategist
    function changeReleaseTime(uint256 _newReleaseTime) external {
        require(ychad == msg.sender);
        require(_newReleaseTime > block.timestamp, "must be in future");
        require(_newReleaseTime < releaseTime, "must be an improvement");
        releaseTime = _newReleaseTime;
    }

    //if both strategist and ychad are in agreement, migrate.
    function migrate(address target) public {
        if (ychad == msg.sender) {
            migrateTargetYchad = target;
            if (migrateTargetStrategist == target) {
                _migrate(target);
            }
        } else if (strategist == msg.sender) {
            migrateTargetStrategist = target;
            if (migrateTargetYchad == target) {
                _migrate(target);
            }
        }
    }

    function _migrate(address target) internal {
        uint256 yfiBalance = yfi.balanceOf(address(this));
        yfi.transfer(target, yfiBalance);
        Swept(address(yfi), yfiBalance, target);
    }

    function sweep(
        address _token,
        uint256 _amount,
        address _target
    ) external {
        // if strategist hasnt been set then ychad can sweep. Backup incase strategist gets set to the wrong address
        require(
            strategist == msg.sender ||
                (strategist == address(0) && ychad == msg.sender),
            "only strategist"
        );
        if (_token == address(yfi)) {
            require(releaseTime < block.timestamp, "escrow period not over");
        }

        _sweep(_token, _amount, _target);
    }

    // a backup function to reclaim yfi if the strategist hasnt claimed in a very long time.
    // likely only could happen with lost keys or death
    function sweepFromDeadStrategist(
        address _token,
        uint256 _amount,
        address _target
    ) external {
        require(ychad == msg.sender, "ychad only");
        require(
            releaseTime.add(FOURYEARS) <= block.timestamp,
            "escrow + 4y not over"
        );
        _sweep(_token, _amount, _target);
    }

    function _sweep(
        address _token,
        uint256 _amount,
        address _target
    ) internal {
        emit Swept(_token, _amount, _target);
        IERC20(_token).safeTransfer(_target, _amount);
    }
}
