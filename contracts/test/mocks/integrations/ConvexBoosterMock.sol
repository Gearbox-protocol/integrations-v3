// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import "./ConvexBaseRewardPoolMock.sol";
import {Test} from "forge-std/Test.sol";

contract BoosterMock is Test {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public crv;
    address public constant registry = address(0x0000000022D53366457F9d5E68Ec105046FC4383);
    uint256 public constant distributionAddressId = 4;
    address public constant voteOwnership = address(0xE478de485ad2fe566d49342Cbd03E49ed7DB3356);
    address public constant voteParameter = address(0xBCfF8B0b9419b9A88c44546519b1e909cF330399);

    uint256 public lockIncentive = 1000; //incentive to crv stakers
    uint256 public stakerIncentive = 450; //incentive to native token stakers
    uint256 public earmarkIncentive = 50; //incentive to users who spend gas to make calls
    uint256 public platformFee = 0; //possible fee to build treasury
    uint256 public constant MaxFees = 2000;
    uint256 public constant FEE_DENOMINATOR = 10000;

    address public owner;
    address public feeManager;
    address public poolManager;
    address public immutable staker;
    address public immutable minter;
    address public rewardFactory;
    address public stashFactory;
    address public tokenFactory;
    address public rewardArbitrator;
    address public voteDelegate;
    address public treasury;
    address public stakerRewards; //cvx rewards
    address public lockRewards; //cvxCrv rewards(crv)
    address public lockFees; //cvxCrv vecrv fees
    address public feeDistro;
    address public feeToken;

    bool public isShutdown;

    /// MOCK PARAMS
    uint256 public index = 0;

    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }

    //index(pid) -> pool
    PoolInfo[] public poolInfo;
    mapping(address => bool) public gaugeMap;

    constructor(address _crv, address _cvx) {
        isShutdown = false;
        staker = address(0);
        owner = msg.sender;
        voteDelegate = msg.sender;
        feeManager = msg.sender;
        poolManager = msg.sender;
        feeDistro = address(0); //address(0xA464e6DCda8AC41e03616F95f4BC98a13b8922Dc);
        feeToken = address(0); //address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
        treasury = address(0);
        minter = _cvx;
        crv = _crv;
    }

    /// END SETTER SECTION ///

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    //create a new pool
    function addPool(address _lptoken) external returns (bool) {
        require(_lptoken != address(0), "!param");

        //the next pool's pid
        uint256 pid = poolInfo.length;

        //create a tokenized deposit
        address token = address(new ERC20Mock("ConvexToken", "CVXTOKEN", 18));
        //create a reward contract for crv rewards
        address newRewardPool = address(new BaseRewardPoolMock(pid, token, crv, address(this)));

        //add the new pool
        poolInfo.push(
            PoolInfo({
                lptoken: _lptoken,
                token: token,
                gauge: address(1),
                crvRewards: newRewardPool,
                stash: address(2),
                shutdown: false
            })
        );

        return true;
    }

    //deposit lp tokens and stake
    function deposit(uint256 _pid, uint256 _amount, bool _stake) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        //send to proxy to stake
        address lptoken = pool.lptoken;
        IERC20(lptoken).safeTransferFrom(msg.sender, address(this), _amount);

        address token = pool.token;
        if (_stake) {
            //mint here and send to rewards on user behalf
            ITokenMinter(token).mint(address(this), _amount);
            address rewardContract = pool.crvRewards;
            IERC20(token).safeApprove(rewardContract, 0);
            IERC20(token).safeApprove(rewardContract, _amount);
            IRewards(rewardContract).stakeFor(msg.sender, _amount);
        } else {
            //add user balance directly
            ITokenMinter(token).mint(msg.sender, _amount);
        }

        index += 1;
        return true;
    }

    //deposit all lp tokens and stake
    function depositAll(uint256 _pid, bool _stake) external returns (bool) {
        address lptoken = poolInfo[_pid].lptoken;
        uint256 balance = IERC20(lptoken).balanceOf(msg.sender);
        deposit(_pid, balance, _stake);
        return true;
    }

    //withdraw lp tokens
    function _withdraw(uint256 _pid, uint256 _amount, address _from, address _to) internal {
        PoolInfo storage pool = poolInfo[_pid];
        address lptoken = pool.lptoken;

        //remove lp balance
        address token = pool.token;
        ITokenMinter(token).burn(_from, _amount);

        //return lp tokens
        IERC20(lptoken).safeTransfer(_to, _amount);

        index += 1;
    }

    //withdraw lp tokens
    function withdraw(uint256 _pid, uint256 _amount) public returns (bool) {
        _withdraw(_pid, _amount, msg.sender, msg.sender);
        return true;
    }

    //withdraw all lp tokens
    function withdrawAll(uint256 _pid) public returns (bool) {
        address token = poolInfo[_pid].token;
        uint256 userBal = IERC20(token).balanceOf(msg.sender);
        withdraw(_pid, userBal);
        return true;
    }

    //allow reward contracts to send here and withdraw to user
    function withdrawTo(uint256 _pid, uint256 _amount, address _to) external returns (bool) {
        address rewardContract = poolInfo[_pid].crvRewards;
        require(msg.sender == rewardContract, "!auth");

        _withdraw(_pid, _amount, msg.sender, _to);
        return true;
    }

    //callback from reward contract when crv is received.
    function rewardClaimed(uint256 _pid, address _address, uint256 _amount) external returns (bool) {
        address rewardContract = poolInfo[_pid].crvRewards;
        require(msg.sender == rewardContract, "!auth");

        //mint reward tokens
        vm.prank(ERC20Mock(minter).minter());
        ITokenMinter(minter).mint(_address, _amount);

        return true;
    }
}
