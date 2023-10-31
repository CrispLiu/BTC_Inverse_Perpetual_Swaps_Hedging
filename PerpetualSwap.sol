// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PerpetualSwap {
    string public name = "Bitcoin Perpetual Swap";
    string public symbol = "BTC-PERPETUAL";

    address public owner; // Address of Strategy contract buying the swap 
    uint256 public margin_ratio; 
    uint256 public contract_size; // decide the BTC to be hedge (1 contract for 1BTC)
    uint256 public margin_account;  // in USD
    uint256 public face_value;  // contract value
    uint256 public requiredMargin_Token;  // Margin required denominated in Bitcoin
    uint256 public requiredMargin_USD;  // Margin required in USD

    uint256[] public Aprices; // Store the daily prices of BTC 
    uint256[] public margins; // Store margin account value each day 
    int256[] public Pnl_Token_vec; // Store Daily PnL  denominated in Bitcoin
    int256[] public Pnl_USD_vec; // Store Daily PnL  denominated in USD

    bool public contractEnabled;  // False after settled
    
    //mapping(address => uint256) public balanceOf;
    event MarginAdded(address indexed account, uint amount);

    constructor(uint256 A_initial_price, uint256 _margin_account, uint256 _margin_ratio, uint256 _contract_size) {

        owner = msg.sender;

        contractEnabled = true; // activiate swap
        contract_size = _contract_size;

        margin_ratio = _margin_ratio;
        Aprices.push(A_initial_price);   

        face_value = A_initial_price * contract_size*10**18 ; // swap value
        margin_account = _margin_account*10**18; // initial margin acount

        requiredMargin_Token = face_value/A_initial_price * _margin_ratio/100 ;
        requiredMargin_USD = requiredMargin_Token * A_initial_price ;

        margins.push(margin_account);

    }

    modifier whenContractEnabled() {
        require(contractEnabled, "Contract is not enabled");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    // Add money to margin account
    function addMargin(uint256 amount) public payable whenContractEnabled{
        margin_account += amount;
        emit MarginAdded(msg.sender, amount);
    }

    // Returen value of current margin account
    function getMargin() public view returns (uint256) {
        return margin_account;
    }

    // Check if current account capital satisfy margin requirment
    function checkMargin() public view returns (bool) {
        return margin_account >= requiredMargin_USD;
    }

    // Extract money out of margin account
    function withdrawMargin(uint amount) public onlyOwner {
        require(margin_account >= amount, "Not enough margin to withdraw");
      //  payable(owner).transfer(amount);
        margin_account -= amount;
    }

    // contract expire 
    function settle() public onlyOwner whenContractEnabled{
        contractEnabled = false;  // 停用合约
    }


    function get_last_Price() public view returns (uint256) {
        return Aprices[Aprices.length - 1];
    }
    function get_last_Pnl() public view returns (int256) {
        return Pnl_USD_vec[Pnl_USD_vec.length - 1];
    }

    function Margin_history() public view returns (uint[] memory) {
        return margins;
    }

    function Pnl_history() public view returns (int[] memory) {
        return Pnl_USD_vec;
    }

    // This function is called whenever a new price recived 
    function update(uint256 AnewPrice) external whenContractEnabled onlyOwner  returns (uint256){

        requiredMargin_USD = requiredMargin_Token * AnewPrice;

        // Calculate Pnl given updated price of token
        uint256 Pnl_token1 =  face_value/get_last_Price();
        uint256 Pnl_token2 =  face_value/AnewPrice ;
        uint256 Pnl_token = 0;
        uint256 Pnl_USD = 0;
  

        if (Pnl_token1 > Pnl_token2){        
            Pnl_token = Pnl_token1- Pnl_token2;
            Pnl_USD = Pnl_token*AnewPrice;
            margin_account -= Pnl_USD;
            Pnl_USD_vec.push(-int256(Pnl_USD));
            Pnl_Token_vec.push(-int256(Pnl_token));
        }
        else{
            Pnl_token = Pnl_token2- Pnl_token1;
            Pnl_USD = Pnl_token*AnewPrice;
            margin_account += Pnl_USD;
            Pnl_USD_vec.push(int256(Pnl_USD));
            Pnl_Token_vec.push(int256(Pnl_token));
        }


        Aprices.push(AnewPrice);

        // Check if trigger margin call
        if (!checkMargin()) {
                  
            uint256 additionalMargin = requiredMargin_USD - margin_account;
            addMargin(additionalMargin);
                     
            return additionalMargin;
        }
        margins.push(margin_account);
        
        return 0;

    }
}