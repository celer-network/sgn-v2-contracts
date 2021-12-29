pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DummySwap {
    address tokenA;
    address tokenB;

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length > 1, "path must have more than 1 token in it");
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        amountAfterSlippage = amountIn * e18 / 1e18;
        IERC20(path[path.length - 1]).transfer(to, );
    }
}
