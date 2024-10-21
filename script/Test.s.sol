import {Script, console} from "forge-std/Script.sol";
contract Test is Script {
    function setUp() public {}

    function run() public {
             // Derivar la clave privada de la dirección por defecto (índice 0)
        uint256 privateKey = vm.deriveKey("test test test test test test test test test test test junk", 0); // Reemplaza con la mnemotécnica si es distinta
        address derivedAddress = vm.addr(privateKey);

        console.log("Derived Address:", derivedAddress);
        console.log("Contract Address:", address(this));
        console.log("Private Key (PK):", privateKey);
    }
}
