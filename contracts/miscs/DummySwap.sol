pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IMintableERC20 {
    function mint(address _to, uint256 _amount) external;
}


contract DummySwap {
    address tokenA;
    address tokenB;
    uint256 fakeSlippage; // 100% = 100 * 1e18
    uint256 hundredPercent;

    constructor(address _tokenA, address _tokenB, uint256 _fakeSlippage) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        fakeSlippage = _fakeSlippage;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(block.timestamp > deadline, "deadline exceeded");
        require(path.length > 1, "path must have more than 1 token in it");
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        // fake simulate slippage
        amountAfterSlippage = amountIn * (hundredPercent - fakeSlippage) / hundredPercent;
        require(amountAfterSlippage > amountOutMin, "bad slippage");
        // directly mint the 
        IMintableERC20(path[path.length - 1]).mint(to, amountAfterSlippage);
        uint256[] amounts = [amountIn, amountAfterSlippage];
        return amounts;
    }

    function setFakeSlippage(uint256 _fakeSlippage) public {
        fakeSlippage = _fakeSlippage;
    }
}
