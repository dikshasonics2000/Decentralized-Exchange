// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {

    address public cryptoDevTokenAddress;

    constructor(address _CryptoDevToken) ERC20(" CryptoDev LP  Token", "CDLP") {
       require(_CryptoDevToken != address(0), "Token Address is a null address ");
        cryptoDevTokenAddress = _CryptoDevToken;
    }

    // use the address(this).balance to get the total eth in the contract as it is only our reserves or liquidity pool.
    function getReserve() public view returns(uint) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this)); // returns total ether in the contract.
    }

    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidity; // this is the lp tokens provided to the user or provider for contributing in the liquidity pool which will be equal to the ether balance for the first user.
        uint ethbalance = address(this).balance; // this is the balance of the contract.
        uint cryptoDevTokenReserve = getReserve(); // this is the total no of token in the reserve or the liquidity pool that is our contract.
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress); // this is the cryptodevtoken contract with erc20 standard

        if(cryptoDevTokenReserve == 0) // if no tokens
        {
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount); // transfer the token from the user or provider to the reserve or contract.
            liquidity = ethbalance; // since it is the first time the lp tokens minted to user will be equal to the ether balance
            _mint(msg.sender, liquidity); // mint function from the erc20 token.
        }
        //_amount is the amount of tokens that user is providing either for adding or removing
        else{
             
             // EthReserve should be the current ethBalance subtracted by the value of ether sent by the user
        // in the current `addLiquidity` call
        //msg.sender returns the address of the user and the msg.value returns the amount or ether of the user he is sending.

        uint ethReserve = ethbalance - msg.value; // this is the value which is the subtraction of the contract ether - ether sent by the user to the contract
        // because `address(this).balance` already contains the `msg.value` user has sent in the given call
    // so we need to subtract it to get the actual input reserve

        // Ratio should always be maintained so that there are no major price impacts when adding liquidity
        // Ratio here is -> (cryptoDevTokenAmount user can add/cryptoDevTokenReserve in the contract) = (Eth Sent by the user/Eth Reserve in the contract);
        // So doing some maths, (cryptoDevTokenAmount user can add) = (Eth Sent by the user * cryptoDevTokenReserve /Eth Reserve);
        uint cryptoDevTokenAmount  = (msg.value * cryptoDevTokenReserve)/(ethReserve);
        require(_amount >= cryptoDevTokenAmount, "Amount of tokens sent is less than the minumum token required");
        cryptoDevToken.transferFrom(msg.sender, address(this), cryptoDevTokenAmount);
        // (LP tokens to be sent to the user (liquidity)/ totalSupply of LP tokens in contract) = (Eth sent by the user)/(Eth reserve in the contract)
        // by some maths -> liquidity =  (totalSupply of LP tokens in contract * (Eth sent by the user))/(Eth reserve in the contract)
        liquidity = (totalSupply() * msg.value)/ ethReserve; //totalsupply is a function in erc20 that returns the total tokens present in the contract
        _mint(msg.sender, liquidity);
        }
        return liquidity;
    } 

    //user or provider wud get the ether for adding liquidity and swap when trader does it.

    function removeLiquidity(uint _amount) public returns (uint, uint) {
        require(_amount > 0, "_amount should be greater than zero");
        uint ethReserve = address(this).balance; // total ether in contract.
        uint _totalSupply = totalSupply();
       // Ratio is -> (Eth sent back to the user) / (current Eth reserve)
    // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    // Then by some maths -> (Eth sent back to the user)
    // = (current Eth reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    uint ethAmount = (ethReserve * _amount) / _totalSupply;
    //Ratio is -> (Crypto Dev sent back to the user) / (current Crypto Dev token reserve)
    // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    // Then by some maths -> (Crypto Dev sent back to the user)
    // = (current Crypto Dev token reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
    uint cryptoDevTokenAmount = (getReserve() * _amount)/(_totalSupply);
        // Burn the sent LP tokens from the user's wallet because they are already sent to
    // remove liquidity
    _burn(msg.sender, _amount);

    payable(msg.sender).transfer(ethAmount);
    ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount); //to transfer the token from the contract to user address.
    return(ethAmount, cryptoDevTokenAmount);//this will transfer the ether from contract to the user account

    }
    // we will be charging them 1% of the inputAmount. input amount is the amount that is the fees given to the pool for swapping

    function getAmountOfTokens(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve  * 100) + inputAmountWithFee;
        return numerator / denominator;
    }
    //input amount is transaction fee
    //msg.value contains the amount of wei (ether / 1e18) sent in the transaction.
    function ethToCryptoDevToken(uint _minTokens) public payable {
        uint256 tokenReserve = getReserve(); // will give the token present in the contract
        uint256 tokensBought = getAmountOfTokens(msg.value, address(this).balance - msg.value, tokenReserve);
        require(tokensBought >= _minTokens, " insufficient output amount ");
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought); //transfer the ether bought
    }

    function cryptoDevTokenTokEth(uint _tokensSold, uint _mintEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmountOfTokens(_tokensSold, tokenReserve, address(this).balance);
    
        require(ethBought >= _mintEth, "insufficient output amount");
        ERC20(cryptoDevTokenAddress).transferFrom(msg.sender, address(this), _tokensSold); // this is bringing tokens fro the user wallet to the contract

        payable(msg.sender).transfer(ethBought);
    }
    

}