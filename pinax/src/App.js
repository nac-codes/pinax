import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Route, Link, Routes, Navigate } from 'react-router-dom';
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

const AdminPanel = ({ addMember }) => {
  
  const [newMember, setNewMember] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    addMember(newMember);
    setNewMember('');
  };

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
    </div>
  );
};

// Pages
const Home = ({ members }) => (
  <div>
    <h1>DAO Member Management</h1>
    <MemberList members={members} />
  </div>
);

const Admin = ({ isAdmin, addMember }) => {
  if (!isAdmin) {
    return <Navigate to="/" />;
  }

  return (
    <div>
      <h1>Admin Area</h1>
      <AdminPanel addMember={addMember} />
    </div>
  );
};

// Main App
function App() {
  const [members, setMembers] = useState([]);
  const [isConnected, setIsConnected] = useState(false);
  const [isAdmin, setIsAdmin] = useState(false);
  const [messageResponse, setMessageResponse] = useState(null);

  const processId = "GpGKJdtAu2cqlEy2DK2mhGIs5i-anZUkCTsFNU5U9OE"; // Replace with your actual process ID

  useEffect(() => {
    checkConnection();
    fetchMembers();
  }, []);

  const checkConnection = async () => {
    if (window.arweaveWallet) {
      try {
        await window.arweaveWallet.connect(['ACCESS_ADDRESS', 'SIGN_TRANSACTION']);
        setIsConnected(true);
        const address = await window.arweaveWallet.getActiveAddress();
        setIsAdmin(members.includes(address)); // Simple admin check
      } catch (error) {
        console.error('Error connecting to ArConnect:', error);
      }
    }
  };

  const fetchResult = async (messageId) => {
    try {
      let { Messages, Spawns, Output, Error } = await result({
        message: messageId,
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
      console.error("Error fetching result:", error);
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
      setMessageResponse(response);
      fetchResult(response);
    } catch (error) {
      console.error("Error sending message:", error);
    }
  };

  const addMember = async (newMemberAddress) => {
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
      setMessageResponse(response);
      fetchResult(response);
    } catch (error) {
      console.error("Error adding member:", error);
    }
  };

  return (
    <Router>
      <div>
        <nav>
          <ul>
            <li><Link to="/">Home</Link></li>
            {isConnected && <li><Link to="/admin">Admin</Link></li>}
          </ul>
        </nav>

        <Routes>
          <Route path="/" element={<Home members={members} />} />
          <Route path="/admin" element={<Admin isAdmin={isAdmin} addMember={addMember} />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;