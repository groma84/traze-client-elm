import './main.css';
import { Elm } from './Main.elm';
import registerServiceWorker from './registerServiceWorker';

const elm = Elm.Main.init({
  node: document.getElementById('root')
});

registerServiceWorker();

const client = mqtt.connect('wss://traze.iteratec.de:9443');

const gamesTopic = 'traze/games';

client.on('connect', function () {
  client.subscribe(gamesTopic);
});

client.on('message', (topic, msg) => {
  console.log(`${topic} message received`, msg.toString());
  elm.ports.receiveData.send({ topic: topic, payload: JSON.parse(msg.toString()) });
});

elm.ports.sendData.subscribe(function (data) {
  console.log('data received from Elm', data);

  switch (data.action) {
    case 'spectateGame':
      client.subscribe(`traze/${data.name}/players`)
      break;
    default:
      console.error('invalid action data', data)
  }
});