import React, { useState, useEffect } from 'react';
import { message, result, createDataItemSigner } from '@permaweb/aoconnect';

// Components
const MemberList = ({ members }) => (
  <div>
    <h2>Member List</h2>
    <ul>
      {members.map((member, index) => (
        <li key={index}>{member}</li>
      ))}
    </ul>
  </div>
);

const AdminPanel = ({ addMember, isAdmin }) => {
  const [newMember, setNewMember] = useState('');
  const [addMemberResult, setAddMemberResult] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    const result = await addMember(newMember);
    setAddMemberResult(result);
    setNewMember('');
  };

  if (!isAdmin) return null;

  return (
    <div>
      <h2>Admin Panel</h2>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={newMember}
          onChange={(e) => setNewMember(e.target.value)}
          placeholder="Enter new member address"
        />
        <button type="submit">Add Member</button>
      </form>
      {addMemberResult && <p>{addMemberResult}</p>}
    </div>
  );
};

// Main App
function App() {
  const [members, setMembers] = useState([]);
  const [isConnected, setIsConnected] = useState(false);
  const [isAdmin, setIsAdmin] = useState(false);
  const [currentAddress, setCurrentAddress] = useState('');

  const processId = "GpGKJdtAu2cqlEy2DK2mhGIs5i-anZUkCTsFNU5U9OE"; // Your process ID

  useEffect(() => {
    checkConnection();
  }, []);

  useEffect(() => {
    if (isConnected) {
      fetchMembers();
    }
  }, [isConnected]);

  useEffect(() => {
    setIsAdmin(members.includes(currentAddress));
  }, [members, currentAddress]);

  const checkConnection = async () => {
    if (window.arweaveWallet) {
      try {
        await window.arweaveWallet.connect(['ACCESS_ADDRESS', 'SIGN_TRANSACTION']);
        setIsConnected(true);
        const address = await window.arweaveWallet.getActiveAddress();
        setCurrentAddress(address);
      } catch (error) {
        console.error('Error connecting to ArConnect:', error);
      }
    }
  };

  const fetchMembers = async () => {
    try {
      const response = await message({
        process: processId,
        tags: [{ name: "Action", value: "GetMembers" }],
        signer: createDataItemSigner(window.arweaveWallet)
      });
      
      console.log("Message response:", response);
      
      let { Messages, Spawns, Output, Error } = await result({
        message: response,
        process: processId,
      });

      console.log("Result data:", { Messages, Spawns, Output, Error });

      if (Messages && Messages.length > 0) {
        const resultData = JSON.parse(Messages[0].Data);
        if (resultData.status === "success") {
          setMembers(resultData.members);
        } else {
          console.error("Error in result data:", resultData.message);
        }
      }
    } catch (error) {
      console.error("Error fetching members:", error);
    }
  };

  const addMember = async (newMemberAddress) => {
    if (!isAdmin) {
      console.error("Only admins can add new members");
      return "Error: Only admins can add new members";
    }

    try {
      const response = await message({
        process: processId,
        tags: [
          { name: "Action", value: "AddMember" },
          { name: "Member_To_Add", value: newMemberAddress }
        ],
        signer: createDataItemSigner(window.arweaveWallet)
      });
      
      console.log("Add member response:", response);
      
      let { Messages, Spawns, Output, Error } = await result({
        message: response,
        process: processId,
      });

      console.log("Result data:", { Messages, Spawns, Output, Error });

      if (Messages && Messages.length > 0) {
        // Assuming the response is a simple string, not JSON
        const resultMessage = Messages[0].Data;
        await fetchMembers(); // Refresh the member list
        return resultMessage;
      } else {
        return "Error: No response received";
      }
    } catch (error) {
      console.error("Error adding member:", error);
      return "Error adding member: " + error.message;
    }
  };

  return (
    <div>
      <h1>DAO Member Management</h1>
      {!isConnected && <button onClick={checkConnection}>Connect to ArConnect</button>}
      {isConnected && (
        <>
          <MemberList members={members} />
          <AdminPanel isAdmin={isAdmin} addMember={addMember} />
        </>
      )}
    </div>
  );
}

export default App;