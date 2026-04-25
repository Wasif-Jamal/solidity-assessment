// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  mapping(address => mapping(address => uint256)) private _allowances;
  mapping(address => uint256) private withdrawableDividends;

  address[] private holders;
  mapping(address => uint256) private holderIndex; // 1-based index

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(_allowances[from][msg.sender] >= value, "Allowance exceeded");
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  function _transfer(address from, address to, uint256 value) internal {
    require(from != address(0), "transfer from zero address");
    require(to != address(0), "transfer to zero address");
    require(balanceOf[from] >= value, "insufficient balance");

    bool isNewHolder = balanceOf[to] == 0;

    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    if (balanceOf[from] == 0) {
        _removeHolder(from);
    }
    if (isNewHolder && value > 0) {
        _addHolder(to);
    }

    emit Transfer(from, to, value);
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "No ETH supplied");
    uint256 amount = msg.value;
    
    bool isNewHolder = balanceOf[msg.sender] == 0;

    balanceOf[msg.sender] = balanceOf[msg.sender].add(amount);
    totalSupply = totalSupply.add(amount);
    
    if (isNewHolder) {
        _addHolder(msg.sender);
    }

    emit Transfer(address(0), msg.sender, amount);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "No tokens to burn");
    
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    
    _removeHolder(msg.sender);

    emit Transfer(msg.sender, address(0), amount);
    
    (bool success, ) = dest.call{value: amount}("");
    require(success, "Transfer failed");
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > holders.length) {
        return address(0);
    }
    return holders[index - 1];
  }

  function recordDividend() external payable override {
    uint256 _value = msg.value;
    require(_value > 0, "No ETH supplied");

    uint256 _totalSupply = totalSupply;
    require(_totalSupply > 0, "No tokens");

    uint256 length = holders.length;
    for (uint256 i = 0; i < length; i++) {
        address holder = holders[i];
        uint256 balance = balanceOf[holder];
        // balance is guaranteed to be > 0 because of efficient holder tracking
        uint256 dividend = _value.mul(balance).div(_totalSupply);
        withdrawableDividends[holder] = withdrawableDividends[holder].add(dividend);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = withdrawableDividends[msg.sender];
    require(amount > 0, "No dividend to withdraw");
    
    withdrawableDividends[msg.sender] = 0;
    
    (bool success, ) = dest.call{value: amount}("");
    require(success, "Transfer failed");
  }

  // Holder Management

  function _addHolder(address account) internal {
    holders.push(account);
    holderIndex[account] = holders.length;
  }

  function _removeHolder(address account) internal {
    uint256 index = holderIndex[account];
    uint256 lastIndex = holders.length;

    if (index != lastIndex) {
        address lastHolder = holders[lastIndex.sub(1)];
        holders[index.sub(1)] = lastHolder;
        holderIndex[lastHolder] = index;
    }

    holders.pop();
    holderIndex[account] = 0;
  }
}