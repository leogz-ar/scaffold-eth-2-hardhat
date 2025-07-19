//
// ██╗     ███████╗ ██████╗  ██████╗ ███████╗
// ██║     ██╔════╝██╔═══██╗██╔════╝ ╚══███╔╝
// ██║     █████╗  ██║   ██║██║  ███╗  ███╔╝
// ██║     ██╔══╝  ██║   ██║██║   ██║ ███╔╝
// ███████╗███████╗╚██████╔╝╚██████╔╝███████╗
// ╚══════╝╚══════╝ ╚═════╝  ╚═════╝ ╚══════╝
// SPDX-License-Identifier: MIT
/** @notice Solidity compiler version
 *   @title SimpleSwap v.4797
 *   @author Leandro Gómez.
 **/
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ERC20 {
    using Math for uint256;

    /// @dev Liquidity pool for a token pair
    struct TkLiquidityPool {
        /// @dev Blueprint describing a token-pair liquidity pool
        uint256 TkDepositA; /// @dev Live reserve balance for token A
        uint256 TkDepositB; /// @dev Live reserve balance for token B
        uint256 totalTkLiquidityPool; /// @dev Total LP tokens issued to represent pool shares
    }

    /// @notice Hash-indexed registry that stores each pair’s pool information
    mapping(bytes32 => TkLiquidityPool) public pairTk;

    /// @notice Initializes the LP token as "Token SimpleSwap" (TSS)
    constructor() ERC20("Token SimpleSwap", "TSS") {}

    /**
     * @notice Unique hash for a token pair
     * @param tokenX X token address
     * @param tokenY Y token address
     * @return Hash of the token pair
     */
    function _pairTkHash(address tokenX, address tokenY) internal pure returns (bytes32) {
        (address tMin, address tMax) = tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX);
        return keccak256(abi.encodePacked(tMin, tMax));
    }

    //#############################
    // ..:: ADD LIQUIDITY ::..
    //#############################
    /**
     * @notice Supplies tokens and mints proportional LP shares
     * @return amountAPost Actual token A contributed
     * @return amountBPost Actual token B contributed
     * @return liquidity LP shares created
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public returns (uint256 amountAPost, uint256 amountBPost, uint256 liquidity) {
        require(block.timestamp <= deadline, "Deadline passed");

        bytes32 poolId = _pairTkHash(tokenA, tokenB);
        TkLiquidityPool storage pool = pairTk[poolId];

        if (pool.totalTkLiquidityPool == 0) {
            amountAPost = amountADesired;
            amountBPost = amountBDesired;
            liquidity = Math.sqrt(amountAPost * amountBPost);
        } else {
            uint256 optimalB = (amountADesired * pool.TkDepositB) / pool.TkDepositA;

            if (optimalB <= amountBDesired) {
                require(optimalB >= amountBMin, "Slippage limit exceeded for token B");
                amountAPost = amountADesired;
                amountBPost = optimalB;
            } else {
                uint256 optimalA = (amountBDesired * pool.TkDepositA) / pool.TkDepositB;
                require(optimalA >= amountAMin, "Slippage limit exceeded for token A");
                amountAPost = optimalA;
                amountBPost = amountBDesired;
            }

            liquidity = Math.min(
                (amountAPost * pool.totalTkLiquidityPool) / pool.TkDepositA,
                (amountBPost * pool.totalTkLiquidityPool) / pool.TkDepositB
            );
        }

        require(liquidity > 0, "No liquidity was minted");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountAPost);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBPost);

        pool.TkDepositA += amountAPost;
        pool.TkDepositB += amountBPost;
        pool.totalTkLiquidityPool += liquidity;

        _mint(to, liquidity);

        return (amountAPost, amountBPost, liquidity);
    }

    //#############################
    // ..:: REMOVE LIQUIDITY ::..
    //#############################
    /**
     * @notice Withdraws liquidity and burns the corresponding LP shares
     */

    /// @notice Wrapper that allows removeLiquidity with tokens in any order
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESS");
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");

        bool reversed = tokenA > tokenB;
        address token0 = reversed ? tokenB : tokenA;
        address token1 = reversed ? tokenA : tokenB;

        uint256 min0 = reversed ? amountBMin : amountAMin;
        uint256 min1 = reversed ? amountAMin : amountBMin;

        (amountA, amountB) = _removeLiquidityCore(token0, token1, liquidity, min0, min1, to, deadline);

        if (reversed) {
            (amountA, amountB) = (amountB, amountA);
        }
    }

    function _removeLiquidityCore(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public returns (uint256 amountAPost, uint256 amountBPost) {
        require(block.timestamp <= deadline, "Deadline passed");
        require(balanceOf(msg.sender) >= liquidity, "Insufficient LP balance");

        bytes32 poolId = _pairTkHash(tokenA, tokenB);
        TkLiquidityPool storage pool = pairTk[poolId];

        amountAPost = (liquidity * pool.TkDepositA) / pool.totalTkLiquidityPool;
        amountBPost = (liquidity * pool.TkDepositB) / pool.totalTkLiquidityPool;

        require(amountAPost >= amountAMin, "Slippage limit exceeded for token A");
        require(amountBPost >= amountBMin, "Slippage limit exceeded for token B");

        pool.TkDepositA -= amountAPost;
        pool.TkDepositB -= amountBPost;
        pool.totalTkLiquidityPool -= liquidity;

        _burn(msg.sender, liquidity);

        IERC20(tokenA).transfer(to, amountAPost);
        IERC20(tokenB).transfer(to, amountBPost);

        return (amountAPost, amountBPost);
    }

    //#######################################
    // ..:: SWAP EXACT TOKENS FOR TOKENS ::..
    //#######################################
    /**
     * @notice Swaps an exact amount of tokens, sending the output to `to`.
     * @dev Wrapper that delegates heavy lifting to `_swapCore` to avoid “stack too deep”.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(block.timestamp <= deadline, "Deadline passed");
        require(path.length == 2 && amountIn > 0, "Swap path invalid");

        return _swapCore(amountIn, amountOutMin, path[0], path[1], to);
    }

    function _swapCore(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address to
    ) internal returns (uint256[] memory amounts) {
        bytes32 poolId = _pairTkHash(tokenIn, tokenOut);
        TkLiquidityPool storage pool = pairTk[poolId];
        require(pool.totalTkLiquidityPool > 0, "Pool lacks liquidity");

        bool tokenInIsA = tokenIn < tokenOut;
        uint256 reserveIn = tokenInIsA ? pool.TkDepositA : pool.TkDepositB;
        uint256 reserveOut = tokenInIsA ? pool.TkDepositB : pool.TkDepositA;

        uint256 outputAmount = getAmountOut(amountIn, reserveIn, reserveOut);
        require(outputAmount >= amountOutMin, "Received amount below minimum");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(to, outputAmount);

        if (tokenInIsA) {
            pool.TkDepositA += amountIn;
            pool.TkDepositB -= outputAmount;
        } else {
            pool.TkDepositB += amountIn;
            pool.TkDepositA -= outputAmount;
        }
        /// @dev Allocate and populate the amounts array
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = outputAmount;
    }

    //#####################
    // ..:: GET PRICE ::..
    //#####################
    /**
     * @notice Gets the spot price of token B denominated in token A
     * @return price quote: units of token B per 1 token A (1e18 precision)
     */
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        bytes32 poolId = _pairTkHash(tokenA, tokenB);
        TkLiquidityPool storage pool = pairTk[poolId];
        require(pool.TkDepositA > 0 && pool.TkDepositB > 0, "Cannot quote price: pool has no liquidity.");

        if (tokenA < tokenB) {
            price = (pool.TkDepositB * 1e18) / pool.TkDepositA;
        } else {
            price = (pool.TkDepositA * 1e18) / pool.TkDepositB;
        }
    }

    //#########################
    // ..:: GET AMOUNT OUT ::..
    //#########################
    /**
     * @notice Calculates expected output for the given input amount
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Bad parameters, try again.");
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }
}
