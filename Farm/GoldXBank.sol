// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract GoldXBank is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; 
        mapping(address => uint256) rewardDebt;
    }
    IERC20 public token; //staking token
    bool public paused;
   
    // Info of each user 
    mapping(address => UserInfo) public userInfo;  
    mapping(address => uint256) public accPerShare;
   
    // operator record
    mapping(address => bool) public operator;
   
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user,uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 amount
    );  
    event AddReward(address rewardToken0, address rewardToken1, uint256 reward0, uint256 reward1);
    event Claim(address indexed user, address rewardToken, uint256 reward);
    event Paused();
    event UnPaused();
    event AddOperator(address _operator);
    event RemoveOperator(address _operator);
    event RewardToken(address _rewardToken);

    modifier isPaused(){
        require(!paused,"contract Locked");
        _;
    }

    modifier isOperator(){
        require(operator[msg.sender], "only operator");
        _;
    }

    constructor(address _factory, IERC20 _staking) public {
        operator[_factory] = true;
        token = _staking;
        emit AddOperator(_factory);
     }
        
     // Update reward variables of the given pool to be up-to-date.
    function addReward(IERC20 rewardToken0, IERC20 rewardToken1, uint256 amount0, uint256 amount1) public {

        uint256 lpSupply = token.balanceOf(address(this));
        if (lpSupply == 0) {
            return;
        }
        if(accPerShare[address(rewardToken0)] == 0){
            emit RewardToken(address(rewardToken0));
        }
        if(accPerShare[address(rewardToken1)] == 0){
            emit RewardToken(address(rewardToken1));
        }

        rewardToken0.transferFrom(msg.sender, address(this), amount0);
        accPerShare[address(rewardToken0)] = accPerShare[address(rewardToken0)].add(
            amount0.mul(1e12).div(lpSupply)
        );

        rewardToken1.transferFrom(msg.sender, address(this), amount1);
        accPerShare[address(rewardToken1)] = accPerShare[address(rewardToken1)].add(
                amount1.mul(1e12).div(lpSupply)
        );

        emit AddReward( address(rewardToken0), address(rewardToken1), amount0, amount1);
    }

    function deposit(uint256 _amount) public isPaused {
        require(_amount > 0, "zero amount");
        address _userAddr = msg.sender;
        UserInfo storage user = userInfo[_userAddr];
        if (user.amount > 0) {
            _claimReward(user, address(token));
        }
        token.safeTransferFrom(
            address(_userAddr),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        emit Deposit(_userAddr,_amount);
    }

    function claim(address[] memory rewardTokens) public isPaused{
        UserInfo storage user = userInfo[msg.sender];
        for(uint256 i=0; i<rewardTokens.length; i++){
            _claimReward(user, rewardTokens[i]);
        }

    }
    function _claimReward(UserInfo storage user, address rewardToken) private   {
        address _userAddr = msg.sender;
        uint256 pendingReward;
        if (user.amount > 0) {
            pendingReward = user.amount.mul(accPerShare[rewardToken]).div(1e12).sub(
            user.rewardDebt[rewardToken]
        );
            safeRewardTransfer(IERC20(rewardToken), _userAddr, pendingReward);
        }
  
        user.rewardDebt[rewardToken] = user.amount.mul(accPerShare[rewardToken]).div(1e12);

        emit Claim(_userAddr, rewardToken, pendingReward);
    }

    function withdraw(uint256 _amount) public isPaused {
        require(_amount > 0, "zero amount");
        address _userAddr = msg.sender;
        UserInfo storage user = userInfo[_userAddr];
        require(user.amount >= _amount, "withdraw: not good");
    
         user.amount = user.amount.sub(_amount);
        token.safeTransfer(address(_userAddr), _amount);
        emit Withdraw(_userAddr, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "zero amount");
        token.safeTransfer(address(msg.sender), user.amount);
        user.amount = 0;
        emit EmergencyWithdraw(msg.sender, user.amount);
       
    }

    // Safe transfer function
    function safeRewardTransfer(IERC20 _reward, address _to, uint256 _amount) internal {
        uint256 _rewardBal = _reward.balanceOf(address(this));
        if (_amount > _rewardBal) {
            _reward.transfer(_to, _rewardBal);
        } else {
            _reward.transfer(_to, _amount);
        }
    }

    function pause() external isOperator{
        require(!paused, "already paused");
        paused = true;
        emit Paused();
    }

    function unPause() external isOperator{
        require(!paused, "already unPaused");
        paused =false;
        emit UnPaused();
    }

    function addOperator(address _addr) external onlyOwner{
        operator[_addr] = true;
        emit AddOperator(_addr);
    }

    function  removeOperator(address _addr) external onlyOwner{
        operator[_addr] = false;
        emit RemoveOperator(_addr);
    }

    function getUserInfo(address _user, address rewardToken) external view returns(uint256, uint256){
        return (userInfo[_user].amount, userInfo[_user].rewardDebt[rewardToken]); 
    }

}
