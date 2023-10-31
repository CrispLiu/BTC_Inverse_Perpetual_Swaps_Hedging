// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PerpetualSwap.sol";

contract Strategy {
    string public name = "Perpetual Swap Hedge";
    string public symbol = "SWAP-STRAT";

    address public owner;
    address public swap_address;  // Address of the perpetual swap contract
    mapping(address => uint256) public balanceOf; // Bank account value
    PerpetualSwap public mySwap;

    int[] public prices; // Store BTC prices

    int[] public PnL_vec; // Store strategy PnL
    int[] public PnL_asset_vec; // Store PnL of holding BTC
    int[] public PnL_hedge_vec; // Store PnL of swap position

    uint256 contract_pos = 0;
    uint256 hedge_ratio = 0;
    uint256 token_hold = 0;

    constructor(uint256 _token_hold, uint256 _hedge_ratio) {
        owner = msg.sender;
        token_hold=_token_hold;
        hedge_ratio = _hedge_ratio;
        contract_pos = _token_hold * hedge_ratio/100;

        // short swap with initial BTC price=47686 and inital margin account=8000
        mySwap = new PerpetualSwap(47686,8000,50,contract_pos);  
        swap_address = address(mySwap); 

        prices.push(47686);
        
        balanceOf[msg.sender] = 47686*2*10**18; // Bank account for margin call

    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute this");
        _;
    }
  
    function get_swap_address() public view returns(address) {
        return swap_address;
    }


    // Insert time series of BTC price for simulation
    function get_price(int[] memory price) public  {
            for(uint i = 0; i < price.length;i++)
        {
            prices.push(price[i]);
        }          
    }

    // Calculate culmulative Pnl for simulation
    function culmulative_Pnl() public view returns(int256) {
        int total = 0;
            for(uint i = 0; i < PnL_vec.length;i++)
        {
            total += PnL_vec[i];
        }          
        return total;
    }


    function Pnl_history() public view returns (int[] memory) {
        return PnL_vec;
    }

    function Pnl_asset_history() public view returns (int[] memory) {
        return PnL_asset_vec;
    }

    function Pnl_hedge_history() public view returns (int[] memory) {
        return PnL_hedge_vec;
    }

    // Hedge strategy simulation
    function simulate() external onlyOwner{
        for(uint i = 1; i < prices.length;i++)
        {
            uint addmargin = mySwap.update(uint256(prices[i]));

            // Trigger margin call
            if(addmargin>0) 
            {
                if (balanceOf[owner] > addmargin) 
                    {
                        balanceOf[owner] -= addmargin;
                    }
                else 
                    {// Not enough money in bank account
                        balanceOf[owner] = 0 ;
                        mySwap.withdrawMargin(addmargin);
                        settle(); 
                        break;
                    }
            }

            // Calculate Pnl
            int assetPnl = int256(token_hold) * (prices[i] - prices[i-1])*10**18; 
            int hedgePnl = mySwap.get_last_Pnl(); 
            int DailyPnl = assetPnl + hedgePnl; //scale

            PnL_vec.push(DailyPnl);
            PnL_asset_vec.push(assetPnl);
            PnL_hedge_vec.push(hedgePnl);
        }
  
    }

    // Transfer money from bank account to margin account
    function deposit(uint256 amount) public {
        require(balanceOf[owner] >= amount, "Not enough money in bank account");
        mySwap.addMargin(amount);
        balanceOf[owner] -= amount;
    }

    // Withdraw money from margin account to bank account 
    function withdraw(uint256 amount) public {
        mySwap.withdrawMargin(amount);
        balanceOf[owner] += amount;
    }

    // Check the moeny in margin account
    function checkBalanceOf() public view returns (uint256) {
        return mySwap.getMargin();
    }

    // Expire swap
    function settle() public onlyOwner {
        mySwap.settle();
    }

}