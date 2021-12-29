pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMintableERC20 {
    function mint(address _to, uint256 _amount) external;
}

contract DummySwap {
    using SafeERC20 for IERC20;

    uint256 fakeSlippage; // 100% = 100 * 1e18
    uint256 hundredPercent;

    constructor(uint256 _fakeSlippage) {
        fakeSlippage = _fakeSlippage;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(deadline != 0 && block.timestamp > deadline, "deadline exceeded");
        require(path.length > 1, "path must have more than 1 token in it");
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        // fake simulate slippage
        uint256 amountAfterSlippage = (amountIn * (hundredPercent - fakeSlippage)) / hundredPercent;
        require(amountAfterSlippage > amountOutMin, "bad slippage");
        // directly mint the
        IERC20(path[path.length - 1]).safeTransfer(to, amountAfterSlippage);
        uint256[] memory ret = new uint256[](2);
        ret[0] = amountIn;
        ret[1] = amountAfterSlippage;
        return ret;
    }

    function setFakeSlippage(uint256 _fakeSlippage) public {
        fakeSlippage = _fakeSlippage;
    }
}
